# PIGSTuner.rb
# A wrapper around the grooveshark rubygem

require 'grooveshark'
require 'thread'
require 'active_support/all'

class PIGSTuner
	def initialize
		init_grooveshark
		@read_io, @write_io = IO.pipe
		@child = nil
		@mutex = Mutex.new
	end

	def init_grooveshark
		puts "Initializing new Grooveshark session"
		@expiration_date = Time.now + (24*60*60)
		@grooveshark_client = Grooveshark::Client.new
		@grooveshark_session = @grooveshark_client.session
	end

	def session_expired?
		return Time.now > @expiration_date
	end

	def play_song(song)
		url = @grooveshark_client.get_song_url(song)
		@child = fork do
			STDIN.reopen(@read_io)
			puts "Playing song: #{song.artist} - #{song.name}"
			`mplayer -really-quiet "#{url}"`
			@mutex.unlock
		end
	end

	def search(query)
		# Check if we need a new Grooveshark session
		if session_expired?
			init_grooveshark
		end

		query.strip!
		songs = @grooveshark_client.search_songs(query)
		return songs.to_json

	end

	def im_feeling_lucky(query)
		# Check if we need a new Grooveshark session
		if session_expired?
			init_grooveshark
		end

		# Ask Grooveshark for a song
		query.strip!
		songs = @grooveshark_client.search_songs(query)
		song = songs.first

		# If we got a song, play it
		unless song.nil?
			if @mutex.locked? then
				execute_tuner_command("stop")
			end
			
			if @mutex.lock then
				play_song(song)
			end
		else
			puts "No results found for #{query}"
		end
		
		return song.to_json
	end

	# Playback controls
	def execute_tuner_command(command)
		commands = {
			"pause_unpause" => " ",
			"stop" => "q"
		}
		if commands.has_key?(command)
			puts "Executing command: #{command}"
			@write_io.write "#{commands[command]}"
			return true
		else
			puts "Unknown command: #{command}"
			return false
		end
	end
end
