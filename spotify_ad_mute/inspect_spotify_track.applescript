-- Quick helper for inspecting the exact metadata Spotify exposes for the
-- currently playing item, including future ad samples.
try
	tell application "Spotify"
		if it is not running then error "Spotify is not running."
		
		set currentPlayerState to (player state as text)
		log "player_state: " & currentPlayerState
		
		if currentPlayerState is "playing" then
			set playingTrack to current track
			log "name: " & (name of playingTrack)
			log "artist: " & (artist of playingTrack)
			log "album: " & (album of playingTrack)
			log "id: " & (id of playingTrack)
			log "spotify_url: " & (spotify url of playingTrack)
		end if
	end tell
on error errMsg
	log "error: " & errMsg
end try
