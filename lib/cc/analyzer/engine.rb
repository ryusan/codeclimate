require "posix/spawn"

module CC
  module Analyzer
    class Engine
      attr_reader :name

      TIMEOUT = 15 * 60 # 15m

      def initialize(name, metadata, code_path, label = SecureRandom.uuid)
        @name = name
        @metadata = metadata
        @code_path = code_path
        @label = label.to_s
      end

      def run(stdout_io)
        pid, _, out, err = POSIX::Spawn.popen4(*docker_run_command)

        t_out = Thread.new do
          out.each_line("\0") do |chunk|
            stdout_io.write(chunk.chomp("\0"))
          end
        end

        t_err = Thread.new do
          err.each_line do |line|
            # N.B. The process will hang if the output's not read. We do nothing
            # with this for now, but should eventually incorporate engine stderr
            # as warnings.
            #$stderr.puts(line.chomp)
          end
        end

        Process.waitpid(pid)
      ensure
        t_out.join if t_out
        t_err.join if t_err
      end

      private

      def docker_run_command
        [
          "docker", "run",
          "--rm",
          "--cap-drop", "all",
          "--label", "com.codeclimate.label=#{@label}",
          "--memory", 512_000_000.to_s, # bytes
          "--memory-swap", "-1",
          "--net", "none",
          "--volume", "#{@code_path}:/code:ro",
          @metadata["image_name"],
          @metadata["command"], # String or Array
        ].flatten.compact
      end
    end
  end
end
