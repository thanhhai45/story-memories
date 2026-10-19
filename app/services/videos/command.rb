require "open3"
require "timeout"

module Videos
  # Chạy ffmpeg/ffprobe an toàn:
  # - luôn truyền danh sách argument (không qua shell, không nội suy chuỗi người dùng)
  # - có timeout, quá hạn thì kill tiến trình
  # - chỉ giữ phần cuối stderr để log
  class Command
    Result = Struct.new(:stdout, :stderr, :status, keyword_init: true)

    MAX_CAPTURE = 64 * 1024

    def self.run!(*args, timeout: 120, chdir: nil)
      new(args.flatten.map(&:to_s), timeout:, chdir:).run!
    end

    def initialize(args, timeout:, chdir: nil)
      raise ArgumentError, "empty command" if args.empty?
      @args = args
      @timeout = timeout
      @chdir = chdir
    end

    def run!
      opts = { pgroup: true }
      opts[:chdir] = @chdir if @chdir

      Open3.popen3(*@args, **opts) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        out_reader = Thread.new { read_limited(stdout) }
        err_reader = Thread.new { read_limited(stderr) }

        unless wait_thr.join(@timeout)
          kill(wait_thr.pid)
          wait_thr.join
          raise Videos::Error.new("#{@args.first} timed out after #{@timeout}s",
                                  user_message: "Dựng video quá thời gian cho phép. Hãy thử với ít ảnh hơn.")
        end

        result = Result.new(stdout: out_reader.value, stderr: err_reader.value, status: wait_thr.value)
        unless result.status.success?
          raise Videos::Error.new("#{@args.first} failed (#{result.status.exitstatus}): #{result.stderr.to_s.lines.last(15).join}")
        end
        result
      end
    rescue Errno::ENOENT
      raise Videos::Error.new("#{@args.first} not found",
                              user_message: "Máy chủ chưa cài FFmpeg. Vui lòng liên hệ quản trị viên.")
    end

    private

    def read_limited(io)
      buffer = +""
      while (chunk = io.read(16 * 1024))
        buffer << chunk
        buffer = buffer[-MAX_CAPTURE..] if buffer.bytesize > MAX_CAPTURE
      end
      buffer
    rescue IOError
      buffer
    end

    def kill(pid)
      Process.kill("-KILL", pid) # cả process group
    rescue Errno::ESRCH, Errno::EPERM
      begin
        Process.kill("KILL", pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
