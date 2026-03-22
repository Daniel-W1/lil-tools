property pollIntervalSeconds : 1
property scriptMutedAudio : false
property savedOutputVolume : missing value
property lastStatusMessage : ""

-- Main watcher loop. Poll Spotify once per second and apply the mute rules.
on run argv
	set blacklistPath to my resolveBlacklistPath(argv)
	my printLine("Watching Spotify with blacklist: " & blacklistPath)
	
	repeat
		my enforceBlacklist(blacklistPath)
		delay pollIntervalSeconds
	end repeat
end run

-- Accept a custom blacklist path or fall back to blacklist.tsv in the current folder.
on resolveBlacklistPath(argv)
	if (count of argv) is greater than 0 then
		set rawPath to item 1 of argv
	else
		set rawPath to "blacklist.tsv"
	end if
	
	if rawPath starts with "~/" then
		set homePath to POSIX path of (path to home folder)
		return homePath & text 3 thru -1 of rawPath
	else if rawPath starts with "/" then
		return rawPath
	else
		return (do shell script "pwd") & "/" & rawPath
	end if
end resolveBlacklistPath

-- Read Spotify state, decide whether the current item should be muted, and
-- only unmute if this script was the thing that muted the Mac previously.
on enforceBlacklist(blacklistPath)
	set spotifyState to my readSpotifyState()
	set playerStateText to playerState of spotifyState
	
	if (isRunning of spotifyState) is false then
		my restoreSystemAudioIfNeeded()
		my reportStatus("Spotify is not running.")
		return
	end if
	
	if playerStateText is not "playing" then
		my restoreSystemAudioIfNeeded()
		my reportStatus("Spotify is " & playerStateText & ".")
		return
	end if
	
	set blacklistState to my loadBlacklist(blacklistPath)
	if (wasFound of blacklistState) is false then
		my restoreSystemAudioIfNeeded()
		my reportStatus("Blacklist not found at " & blacklistPath)
		return
	end if
	
	set blacklistEntries to entries of blacklistState
	set trackName to trackName of spotifyState
	set trackArtist to trackArtist of spotifyState
	set trackAlbum to trackAlbum of spotifyState
	set muteReason to my muteReasonForTrack(spotifyState, blacklistEntries)
	
	if muteReason is not "" then
		my muteSystemAudioIfNeeded()
		my reportStatus("Muted (" & muteReason & "): " & trackName & " - " & trackArtist & " (" & trackAlbum & ")")
	else
		my restoreSystemAudioIfNeeded()
		my reportStatus("Allowed: " & trackName & " - " & trackArtist & " (" & trackAlbum & ")")
	end if
end enforceBlacklist

-- Spotify's AppleScript dictionary exposes track metadata plus generic item
-- identifiers, which we use for both manual blacklist matches and ad heuristics.
on readSpotifyState()
	try
		tell application "Spotify"
			if it is running then
				set currentPlayerState to (player state as text)
				if currentPlayerState is "playing" then
					set playingTrack to current track
					return {isRunning:true, playerState:currentPlayerState, trackName:(name of playingTrack), trackArtist:(artist of playingTrack), trackAlbum:(album of playingTrack), trackID:(id of playingTrack), trackURL:(spotify url of playingTrack)}
				else
					return {isRunning:true, playerState:currentPlayerState, trackName:"", trackArtist:"", trackAlbum:"", trackID:"", trackURL:""}
				end if
			end if
		end tell
	on error
		-- Spotify may not be installed, may not be running, or Apple Events access may be denied.
	end try
	
	return {isRunning:false, playerState:"stopped", trackName:"", trackArtist:"", trackAlbum:"", trackID:"", trackURL:""}
end readSpotifyState

-- Read a tab-separated blacklist file and skip blank lines plus # comments.
on loadBlacklist(blacklistPath)
	set entries to {}
	
	try
		set fileContents to read (POSIX file blacklistPath) as «class utf8»
	on error
		return {wasFound:false, entries:entries}
	end try
	
	repeat with rawLine in paragraphs of fileContents
		set cleanedLine to my trimText(contents of rawLine)
		if cleanedLine is not "" and cleanedLine does not start with "#" then
			set parsedEntry to my parseBlacklistLine(cleanedLine)
			if parsedEntry is not missing value then set end of entries to parsedEntry
		end if
	end repeat
	
	return {wasFound:true, entries:entries}
end loadBlacklist

-- Each row is: title<TAB>artist<TAB>album. Blank fields behave as wildcards.
on parseBlacklistLine(rawLine)
	set oldTIDs to AppleScript's text item delimiters
	set AppleScript's text item delimiters to tab
	set rawFields to text items of rawLine
	set AppleScript's text item delimiters to oldTIDs
	
	set titleFilter to ""
	set artistFilter to ""
	set albumFilter to ""
	
	if (count of rawFields) is greater than or equal to 1 then set titleFilter to my trimText(item 1 of rawFields)
	if (count of rawFields) is greater than or equal to 2 then set artistFilter to my trimText(item 2 of rawFields)
	if (count of rawFields) is greater than or equal to 3 then set albumFilter to my trimText(item 3 of rawFields)
	
	if titleFilter is "" and artistFilter is "" and albumFilter is "" then return missing value
	return {title:titleFilter, artist:artistFilter, album:albumFilter}
end parseBlacklistLine

-- A row matches only when all populated fields match the currently playing track.
on trackMatchesBlacklist(trackName, trackArtist, trackAlbum, blacklistEntries)
	repeat with entry in blacklistEntries
		set currentEntry to contents of entry
		if my fieldMatches(trackName, title of currentEntry) and my fieldMatches(trackArtist, artist of currentEntry) and my fieldMatches(trackAlbum, album of currentEntry) then
			return true
		end if
	end repeat
	
	return false
end trackMatchesBlacklist

-- Ads take priority over the manual blacklist so status output stays specific.
on muteReasonForTrack(spotifyState, blacklistEntries)
	set trackName to trackName of spotifyState
	set trackArtist to trackArtist of spotifyState
	set trackAlbum to trackAlbum of spotifyState
	set trackID to trackID of spotifyState
	set trackURL to trackURL of spotifyState
	
	if my isLikelySpotifyAd(trackName, trackArtist, trackAlbum, trackID, trackURL) then return "ad"
	if my trackMatchesBlacklist(trackName, trackArtist, trackAlbum, blacklistEntries) then return "blacklist"
	return ""
end muteReasonForTrack

-- Spotify does not expose a documented "is ad" AppleScript property, so these
-- checks intentionally rely on metadata patterns observed in the desktop app.
on isLikelySpotifyAd(trackName, trackArtist, trackAlbum, trackID, trackURL)
	if my containsText(trackID, "spotify:ad") then return true
	if my containsText(trackURL, "spotify:ad") then return true
	if my containsText(trackName, "advertisement") then return true
	if my containsText(trackArtist, "advertisement") then return true
	if my containsText(trackAlbum, "advertisement") then return true
	
	-- Upgrade prompts often come through as Spotify-owned ad content.
	if my equalsText(trackArtist, "Spotify") and (my containsText(trackName, "upgrade") or my containsText(trackName, "premium") or my containsText(trackAlbum, "upgrade") or my containsText(trackAlbum, "premium")) then
		return true
	end if
	
	return false
end isLikelySpotifyAd

-- Blank blacklist fields are wildcards; populated ones use case-insensitive
-- substring matching so the file can stay simple and forgiving.
on fieldMatches(trackValue, blacklistValue)
	if blacklistValue is "" then return true
	if trackValue is "" then return false
	return my containsText(trackValue, blacklistValue)
end fieldMatches

on containsText(haystackText, needleText)
	if needleText is "" then return true
	if haystackText is "" then return false
	
	ignoring case
		return (my trimText(haystackText)) contains (my trimText(needleText))
	end ignoring
end containsText

on equalsText(leftText, rightText)
	ignoring case
		return (my trimText(leftText)) is (my trimText(rightText))
	end ignoring
end equalsText

-- Save the prior output volume so we can restore it after the blocked item ends.
on muteSystemAudioIfNeeded()
	if scriptMutedAudio then return
	
	set volumeSettings to get volume settings
	set currentlyMuted to output muted of volumeSettings
	
	if currentlyMuted then return
	
	set savedOutputVolume to output volume of volumeSettings
	set volume with output muted
	set scriptMutedAudio to true
end muteSystemAudioIfNeeded

-- Only undo mute state that this script created.
on restoreSystemAudioIfNeeded()
	if scriptMutedAudio is false then return
	
	if savedOutputVolume is missing value then
		set volume without output muted
	else
		set volume output volume savedOutputVolume
		set volume without output muted
	end if
	
	set scriptMutedAudio to false
	set savedOutputVolume to missing value
end restoreSystemAudioIfNeeded

-- Avoid logging the same message every poll cycle.
on reportStatus(messageText)
	if messageText is lastStatusMessage then return
	set lastStatusMessage to messageText
	my printLine(messageText)
end reportStatus

on printLine(messageText)
	log messageText
end printLine

-- Trim leading and trailing whitespace so TSV parsing is more tolerant.
on trimText(inputText)
	set workingText to inputText as text
	
	repeat while workingText is not "" and (character 1 of workingText is space or character 1 of workingText is tab or character 1 of workingText is return or character 1 of workingText is linefeed)
		if (count of characters of workingText) is 1 then
			return ""
		end if
		set workingText to text 2 thru -1 of workingText
	end repeat
	
	repeat while workingText is not "" and (character -1 of workingText is space or character -1 of workingText is tab or character -1 of workingText is return or character -1 of workingText is linefeed)
		if (count of characters of workingText) is 1 then
			return ""
		end if
		set workingText to text 1 thru -2 of workingText
	end repeat
	
	return workingText
end trimText
