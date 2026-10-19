module Videos
  # Lỗi có kiểm soát trong quá trình dựng video.
  # `user_message` là câu an toàn để hiển thị cho người dùng;
  # `message` có thể chứa chi tiết kỹ thuật và chỉ ghi vào log server.
  class Error < StandardError
    attr_reader :user_message

    def initialize(message = nil, user_message: nil)
      super(message)
      @user_message = user_message || "Không dựng được video. Vui lòng thử lại."
    end
  end
end
