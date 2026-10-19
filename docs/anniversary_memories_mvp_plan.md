# Anniversary Memories --- Kế hoạch triển khai MVP từ đầu đến cuối

> **Mục tiêu:** Xây dựng website cá nhân biến ảnh và vài dòng tâm sự
> thành video kỷ niệm có lời dẫn AI, nhạc nền, hiệu ứng chuyển cảnh và
> file MP4 để tải về/chia sẻ.
>
> **Deadline mục tiêu:** 25/10/2026\
> **Phạm vi:** MVP cá nhân, chưa có Authentication, chưa cần thanh toán
> hay SaaS multi-user.\
> **Stack:** Ruby on Rails MVC, ERB, Hotwire/Turbo, StimulusJS,
> PostgreSQL, Active Storage, Solid Queue, LLM API, FFmpeg.

------------------------------------------------------------------------

## 1. Tầm nhìn sản phẩm

Người dùng tạo một dự án kỷ niệm như ngày cưới, ngày yêu nhau, sinh
nhật, kỷ niệm gia đình hoặc một cột mốc đáng nhớ. Họ tải ảnh lên, nhập
thông tin và một đoạn tâm sự. AI tạo tiêu đề, lời dẫn và lời kết.
Website sử dụng template cố định để ghép ảnh, chữ, hiệu ứng và nhạc
thành video MP4.

### Ví dụ đầu vào

-   Dịp: Kỷ niệm 6 năm ngày cưới
-   Khoảng thời gian: 2020--2026
-   Ảnh: 10--30 ảnh
-   Tâm sự: "Sáu năm qua có nhiều thay đổi, có những lúc khó khăn nhưng
    chúng mình vẫn luôn đồng hành cùng nhau."
-   Phong cách: Lãng mạn, ấm áp
-   Nhạc: Piano nhẹ nhàng

### Ví dụ đầu ra

-   Tiêu đề: "6 năm cùng nhau"
-   Phụ đề: "2020 --- 2026"
-   Các đoạn lời dẫn theo chương
-   Lời kết cá nhân hóa
-   Video MP4 có ảnh, chữ, chuyển cảnh và nhạc nền
-   Trang xem video và nút tải xuống

**Nguyên tắc sản phẩm:** AI hỗ trợ viết câu chuyện; FFmpeg dựng video
theo template xác định. Không dùng AI video generation trong MVP để
tránh tăng chi phí và độ phức tạp.

------------------------------------------------------------------------

## 2. Mục tiêu và tiêu chí hoàn thành

### Phải có trước ngày 25/10

-   [ ] Tạo và chỉnh sửa dự án kỷ niệm.
-   [ ] Upload nhiều ảnh.
-   [ ] Xem trước, xóa và sắp xếp ảnh.
-   [ ] Nhập thông tin kỷ niệm và ghi chú.
-   [ ] Tạo lời dẫn tiếng Việt bằng AI.
-   [ ] Cho phép sửa nội dung AI trước khi dựng.
-   [ ] Có ít nhất 2 template video.
-   [ ] Ghép ảnh, chữ, nhạc và hiệu ứng thành MP4.
-   [ ] Hiển thị trạng thái render.
-   [ ] Xem và tải video.
-   [ ] Có trang chia sẻ không cần đăng nhập nhưng dùng token khó đoán.
-   [ ] Chạy được local và deploy được nếu còn thời gian.

### Chưa làm trong MVP

-   Authentication, phân quyền nhiều người dùng
-   Thanh toán, subscription
-   AI tạo hình ảnh/video mới
-   AI voice-over
-   Trình chỉnh sửa video dạng timeline phức tạp
-   Ứng dụng mobile
-   Social feed, bình luận
-   Nhiều ngôn ngữ
-   Hệ thống SaaS multi-tenant

### Tiêu chí nghiệm thu cuối cùng

Một người có thể mở website, tạo kỷ niệm, tải ít nhất 10 ảnh, nhập câu
chuyện, sinh và chỉnh sửa lời dẫn AI, chọn template, render video, xem
MP4 và tải video xuống mà không cần đăng nhập.

------------------------------------------------------------------------

## 3. Công nghệ và quyết định kiến trúc

  -----------------------------------------------------------------------
  Thành phần              Lựa chọn                Vai trò
  ----------------------- ----------------------- -----------------------
  Backend                 Ruby on Rails 8.x, MVC  Routing, models,
                                                  controllers, views

  UI                      ERB + Tailwind CSS      Giao diện
                                                  server-rendered

  JavaScript              StimulusJS + Turbo      Upload preview, sắp xếp
                                                  ảnh, cập nhật trạng
                                                  thái

  Database                PostgreSQL              Lưu dữ liệu dự án và
                                                  kịch bản

  Upload                  Active Storage          Quản lý file ảnh và
                                                  video

  Background jobs         Solid Queue             AI generation và video
                                                  rendering

  AI                      LLM API qua service     Sinh lời dẫn/kịch bản
                          object                  có cấu trúc

  Video                   FFmpeg/ffprobe          Ghép ảnh, chữ, nhạc,
                                                  xuất MP4

  Storage local           Disk service khi phát   Giúp bắt đầu nhanh
                          triển                   

  Storage production      S3 hoặc dịch vụ tương   Lưu ảnh và video khi
                          thích                   deploy

  Deploy                  Một máy chủ/worker ban  Giảm độ phức tạp MVP
                          đầu                     
  -----------------------------------------------------------------------

### Nguyên tắc kiến trúc

1.  Rails giữ vai trò MVC chính; không dùng React hoặc Next.js.
2.  Controller mỏng, nghiệp vụ nằm trong service objects.
3.  Tác vụ gọi AI và render video chạy background, không giữ HTTP
    request mở lâu.
4.  Mỗi lần render tạo một `VideoRender` riêng để theo dõi trạng thái và
    lỗi.
5.  API key của AI chỉ nằm trong credentials hoặc environment variables.
6.  Không lưu dữ liệu cá nhân không cần thiết.
7.  Khi chưa có authentication, không cho phép liệt kê tất cả dự án hoặc
    dùng ID tuần tự làm đường dẫn chia sẻ công khai.

------------------------------------------------------------------------

## 4. Khởi tạo project

> Thực hiện trên môi trường đã cài Ruby, Rails, PostgreSQL và Node/Bun
> nếu pipeline CSS/JS đang sử dụng cần đến chúng.

### 4.1 Tạo ứng dụng

``` bash
rails new anniversary_memories -d postgresql --css tailwind
cd anniversary_memories
bin/rails db:create
bin/rails server
```

Nếu môi trường hiện tại sử dụng phiên bản Rails khác, dùng phiên bản ổn
định đang cài và tránh nâng cấp dependency giữa sprint.

### 4.2 Cài Active Storage

``` bash
bin/rails active_storage:install
bin/rails db:migrate
```

Dùng local disk service trong development. Khi deploy, cấu hình S3 bằng
biến môi trường và credentials phù hợp.

### 4.3 Cài các gem cần thiết

Kiểm tra Gemfile hiện có trước khi thêm gem. Các thành phần có thể cần:

``` ruby
# Gemfile
gem "image_processing", "~> 1.2"
```

-   `image_processing`: tạo thumbnail/variant cho ảnh nếu cần.
-   PostgreSQL adapter thường đã có trong Gemfile do tạo project với
    `-d postgresql`.
-   Solid Queue có thể đã được cấu hình sẵn tùy phiên bản Rails; kiểm
    tra trước khi cài hoặc tạo lại cấu hình.
-   Không cần thêm gem FFmpeg bắt buộc; có thể gọi executable `ffmpeg`
    bằng service Ruby với đối số dạng array an toàn.

### 4.4 Cài FFmpeg

macOS với Homebrew:

``` bash
brew install ffmpeg
ffmpeg -version
ffprobe -version
```

Ubuntu/Debian:

``` bash
sudo apt update
sudo apt install -y ffmpeg
ffmpeg -version
```

Kiểm tra FFmpeg chạy được **ngay ngày đầu**. Đây là rủi ro kỹ thuật lớn
nhất của deadline.

------------------------------------------------------------------------

## 5. Data model

Mô hình tối thiểu gồm `Memory`, `MemoryPhoto`, `Story`, `VideoTemplate`,
`VideoRender`. Active Storage quản lý file đính kèm.

### 5.1 Memory

Lưu thông tin dự án kỷ niệm.

Các trường gợi ý:

-   `title:string`, bắt buộc
-   `occasion:string`, ví dụ `anniversary`, `birthday`, `relationship`,
    `family`, `custom`
-   `start_date:date`, nullable
-   `end_date:date`, nullable
-   `person_names:string`, nullable
-   `story_notes:text`, nullable
-   `style:string`, default `romantic`
-   `status:string`, default `draft`
-   `share_token:string`, unique, nullable cho đến khi bật chia sẻ
-   `share_enabled:boolean`, default `false`

Quan hệ:

-   `has_many :memory_photos, -> { order(position: :asc) }, dependent: :destroy`
-   `has_many :stories, dependent: :destroy`
-   `has_many :video_renders, dependent: :destroy`

### 5.2 MemoryPhoto

-   `memory:references`, foreign key
-   `position:integer`, default `0`
-   `caption:string`, nullable
-   `taken_at:date`, nullable
-   `alt_text:string`, nullable
-   `has_one_attached :image`

Validation: - Ảnh phải là JPEG, PNG hoặc WebP. - Giới hạn kích thước
file theo cấu hình, ví dụ 15 MB/ảnh. - Giới hạn số ảnh trong MVP, ví dụ
tối đa 30 ảnh/dự án. - Không tin MIME type do client gửi; kiểm tra nội
dung file khi có thể. - Chỉ chấp nhận attachment hợp lệ trước khi đưa
vào FFmpeg.

### 5.3 Story

-   `memory:references`, foreign key
-   `status:string`, default `pending`
-   `prompt_data:jsonb`, default `{}`
-   `generated_content:jsonb`, default `{}`
-   `error_message:text`, nullable
-   `generated_at:datetime`, nullable

Lưu JSON có cấu trúc, ví dụ title, subtitle, scenes, ending. Có thể giữ
nhiều phiên bản lời dẫn để người dùng chọn lại.

### 5.4 VideoTemplate

-   `name:string`
-   `slug:string`, unique
-   `description:text`
-   `configuration:jsonb`, default `{}`
-   `active:boolean`, default `true`

Tạo seed cho ít nhất hai template: `romantic_cinematic` và
`photo_album`.

### 5.5 VideoRender

-   `memory:references`, foreign key
-   `story:references`, nullable
-   `video_template:references`, nullable
-   `status:string`, default `queued`
-   `progress:integer`, default `0`
-   `error_message:text`, nullable
-   `started_at:datetime`, nullable
-   `finished_at:datetime`, nullable
-   `has_one_attached :output_video`

Các trạng thái gợi ý: `queued`, `processing`, `completed`, `failed`.

### 5.6 Tạo models

Có thể tạo bằng generator rồi chỉnh sửa migration trước khi migrate:

``` bash
bin/rails generate model Memory \
  title:string occasion:string start_date:date end_date:date \
  person_names:string story_notes:text style:string status:string \
  share_token:string share_enabled:boolean

bin/rails generate model MemoryPhoto \
  memory:references position:integer caption:string taken_at:date alt_text:string

bin/rails generate model Story \
  memory:references status:string prompt_data:jsonb generated_content:jsonb \
  error_message:text generated_at:datetime

bin/rails generate model VideoTemplate \
  name:string slug:string description:text configuration:jsonb active:boolean

bin/rails generate model VideoRender \
  memory:references story:references video_template:references \
  status:string progress:integer error_message:text \
  started_at:datetime finished_at:datetime
```

Sau khi tạo generator, chỉnh migration để bổ sung defaults, null
constraints, index và foreign key phù hợp. Dùng
`has_one_attached :image` và `has_one_attached :output_video` trong
model; không tạo cột file thủ công.

------------------------------------------------------------------------

## 6. Routes và controllers

### 6.1 Routes đề xuất

``` ruby
# config/routes.rb
Rails.application.routes.draw do
  root "memories#index"

  resources :memories do
    resources :photos, only: %i[create update destroy], controller: "memory_photos"
    resource :story, only: %i[show create update], controller: "memory_stories"
    resources :video_renders, only: %i[create show], controller: "video_renders"
  end

  get "/s/:token", to: "shared_memories#show", as: :shared_memory
end
```

Nếu dùng `resources :photos` lồng trong `memories`, cần đảm bảo
controller và route helper nhất quán. Chạy `bin/rails routes` sau khi
cấu hình.

### 6.2 Controller responsibilities

-   `MemoriesController`: index, new, create, show, edit, update,
    destroy.
-   `MemoryPhotosController`: upload, update caption/position, destroy.
-   `MemoryStoriesController`: yêu cầu sinh AI, xem nội dung, lưu chỉnh
    sửa.
-   `VideoRendersController`: tạo render job, hiển thị trạng thái.
-   `SharedMemoriesController`: chỉ hiển thị kỷ niệm khi token hợp lệ và
    `share_enabled` bật.

Không đưa logic prompt, FFmpeg command hoặc timeline vào controller.

### 6.3 An toàn khi chưa có Authentication

Vì chưa có đăng nhập: - Đây là ứng dụng cá nhân hoặc môi trường thử
nghiệm, không phải website multi-user công khai. - Không tạo trang index
công khai liệt kê dự án cá nhân nếu chưa có nhu cầu. - Trang share dùng
token ngẫu nhiên đủ dài, không dùng ID database. - Cho phép tắt chia sẻ
và đổi token nếu cần thu hồi link. - Không để lộ API key trong HTML,
JavaScript, log hoặc URL. - Thêm giới hạn request và upload nếu mở ra
Internet. - Nếu deploy public, cân nhắc basic auth hoặc giới hạn truy
cập cho trang quản trị cá nhân. - Không xem token share như cơ chế xác
thực chủ sở hữu; ai có link có thể xem nếu link còn hiệu lực.

------------------------------------------------------------------------

## 7. UI/UX và các trang

### Trang 1 --- Dashboard cá nhân

-   Tiêu đề "Những khoảnh khắc đáng nhớ"
-   Nút "Tạo kỷ niệm mới"
-   Danh sách dự án gần đây
-   Thumbnail ảnh bìa, tên kỷ niệm, trạng thái render

### Trang 2 --- Tạo/chỉnh sửa kỷ niệm

Trường nhập: - Tên kỷ niệm - Loại dịp - Ngày bắt đầu/kết thúc - Tên
người liên quan - Phong cách: lãng mạn, vui tươi, hoài niệm - Đoạn tâm
sự - Chọn template

### Trang 3 --- Quản lý ảnh

-   Khu vực upload kéo-thả
-   Thumbnail preview
-   Xóa ảnh
-   Sắp xếp bằng kéo-thả
-   Caption tùy chọn
-   Chọn ảnh bìa
-   Hiển thị số lượng ảnh và giới hạn

Dùng StimulusJS cho preview và sắp xếp. Backend phải lưu lại thứ tự;
không chỉ thay đổi DOM.

### Trang 4 --- Nội dung AI

-   Nút "Viết câu chuyện giúp tôi"
-   Trạng thái đang tạo
-   Tiêu đề, phụ đề, lời dẫn từng đoạn, lời kết
-   Các trường có thể chỉnh sửa
-   Nút "Lưu nội dung"
-   Nút "Tạo lại" nếu người dùng muốn một phiên bản khác

### Trang 5 --- Render video

-   Chọn template
-   Chọn nhạc từ danh sách được phép sử dụng
-   Nút "Tạo video"
-   Trạng thái: đang chờ, đang xử lý, hoàn tất, lỗi
-   Khi hoàn tất: video player, tải MP4, sao chép link chia sẻ

### Trang 6 --- Trang chia sẻ

-   Hiển thị video và thông tin kỷ niệm
-   Không hiển thị nút chỉnh sửa
-   Không hiển thị dữ liệu nội bộ, lỗi, prompt hoặc thông tin hệ thống
-   Chỉ hoạt động khi chia sẻ được bật

------------------------------------------------------------------------

## 8. StimulusJS controllers

### `photo_upload_controller.js`

Trách nhiệm: - Preview ảnh được chọn trước khi upload. - Hiển thị tên và
dung lượng file. - Cho phép xóa ảnh khỏi danh sách chờ upload. - Báo lỗi
nếu vượt giới hạn.

Không thay thế validation phía server bằng validation JavaScript.

### `photo_sort_controller.js`

Trách nhiệm: - Kéo-thả thumbnail để sắp xếp. - Gửi thứ tự mới tới
endpoint cập nhật position. - Hiển thị trạng thái lưu. - Có thể dùng thư
viện sortable nhỏ nếu cần; không cần tự viết thuật toán drag-and-drop từ
đầu khi deadline ngắn.

### `story_form_controller.js`

Trách nhiệm: - Gửi yêu cầu sinh AI bằng form Rails/Turbo. - Hiển thị
loading. - Không gửi API key từ browser. - Cho phép người dùng chỉnh sửa
và lưu nội dung trả về.

### `video_render_controller.js`

Trách nhiệm: - Bắt đầu render. - Hiển thị trạng thái job. - Cập nhật
tiến độ bằng polling nhẹ hoặc Turbo Streams. - Dừng polling khi
`completed` hoặc `failed`.

Ưu tiên cách đơn giản, ổn định. Không cần xây dựng WebSocket riêng trong
MVP.

------------------------------------------------------------------------

## 9. AI story generation

### 9.1 Input

Truyền những dữ liệu cần thiết: - Occasion - Khoảng thời gian - Tên
người - Tâm sự - Phong cách - Caption ảnh nếu có - Ngôn ngữ đầu ra

Không gửi ảnh riêng tư đến nhà cung cấp AI trừ khi thật sự cần và người
dùng hiểu việc đó.

### 9.2 Output schema

Ví dụ:

``` json
{
  "title": "6 năm cùng nhau",
  "subtitle": "2020 — 2026",
  "tone": "romantic",
  "scenes": [
    {
      "title": "Ngày chúng ta bắt đầu",
      "narration": "Một hành trình mới bắt đầu...",
      "photo_positions": [1, 2, 3]
    },
    {
      "title": "Những năm tháng đồng hành",
      "narration": "Qua những niềm vui và thử thách...",
      "photo_positions": [4, 5, 6]
    }
  ],
  "ending": "Mong chúng ta còn thật nhiều năm tháng bên nhau."
}
```

### 9.3 Prompt principles

-   Chỉ dùng sự kiện được người dùng cung cấp.
-   Không tự bịa ngày gặp nhau, cầu hôn, con cái hoặc chuyến đi.
-   Giọng văn tự nhiên, giàu cảm xúc nhưng không sến quá mức.
-   Độ dài phù hợp video ngắn.
-   Trả về JSON đúng schema.
-   Không đưa chỉ dẫn từ nội dung người dùng thành lệnh hệ thống.
-   Giới hạn token và số lần gọi để kiểm soát chi phí.

### 9.4 Service object

Tạo `app/services/stories/generator.rb`: - Nhận `Memory`. - Chuẩn hóa
input. - Gọi LLM API bằng server-side HTTP client. - Parse JSON và
validate schema. - Lưu vào `Story`. - Xử lý timeout, rate limit,
response lỗi. - Không ghi API key hoặc nội dung nhạy cảm vào log.

Tạo `GenerateStoryJob` để thực hiện ở background nếu API có thể mất thời
gian. Với MVP có thể trả trạng thái qua Turbo/polling.

------------------------------------------------------------------------

## 10. Video rendering với FFmpeg

### 10.1 Quy trình

1.  Đọc `Memory`, `MemoryPhoto`, `Story` và template.
2.  Kiểm tra ảnh và nhạc.
3.  Tạo thư mục làm việc tạm riêng cho từng render.
4.  Tạo từng scene hoặc một input sequence có thời lượng rõ ràng.
5.  Thêm hiệu ứng zoom/pan nhẹ, fade và chữ.
6.  Thêm nhạc nền, chuẩn hóa âm lượng và fade-out.
7.  Ghép scene thành MP4.
8.  Dùng `ffprobe` kiểm tra output.
9.  Upload output vào Active Storage.
10. Cập nhật trạng thái render; dọn file tạm kể cả khi lỗi.

### 10.2 Template MVP

**Template A: Romantic Cinematic** - Tỷ lệ 16:9 - Nền tối hoặc blur
background khi ảnh không cùng tỷ lệ - Tiêu đề mở đầu - Hiệu ứng zoom
chậm - Fade/dissolve - Lời kết

**Template B: Photo Album** - Khung ảnh kiểu album - Chữ ngắn theo từng
chương - Chuyển cảnh đơn giản - Nhạc nền nhẹ

### 10.3 Thông số mặc định

-   Ảnh: tối đa 30 ảnh trong MVP
-   Thời lượng: khoảng 45--90 giây
-   Output: MP4, H.264 video, AAC audio
-   Khung hình: 1920×1080 nếu tài nguyên cho phép; có thể render
    1280×720 trước để giảm thời gian
-   FPS: 24 hoặc 30
-   Chỉ dùng nhạc đã được cấp quyền hoặc có giấy phép phù hợp

### 10.4 An toàn khi gọi FFmpeg

-   Dùng `Open3.capture3` hoặc API tương đương với danh sách arguments,
    không ghép chuỗi shell từ input người dùng.
-   Không cho người dùng truyền trực tiếp đường dẫn file hoặc tham số
    FFmpeg.
-   Dùng tên file nội bộ do hệ thống tạo.
-   Giới hạn thời gian chạy, kích thước file và số ảnh.
-   Xóa file tạm sau render.
-   Kiểm tra output và bắt lỗi.
-   Không cho phép URL tùy ý làm input FFmpeg, tránh SSRF và truy cập
    file không được phép.

### 10.5 Service object

Tạo `app/services/videos/timeline_builder.rb` để: - Chuyển Story JSON
thành các scene. - Gán ảnh cho scene. - Tính thời lượng từng ảnh. - Tạo
cấu hình render dễ kiểm thử.

Tạo `app/services/videos/renderer.rb` để: - Tạo file tạm. - Gọi
FFmpeg. - Kiểm tra file bằng ffprobe. - Trả output path hoặc lỗi có kiểm
soát.

Tạo `RenderVideoJob` để gọi renderer và cập nhật `VideoRender`.

------------------------------------------------------------------------

## 11. Background jobs và trạng thái

### Jobs đề xuất

-   `GenerateStoryJob`: gọi AI và lưu nội dung.
-   `RenderVideoJob`: render MP4.
-   `CleanupTemporaryFilesJob`: dọn file tạm nếu cần.

### Trạng thái render

``` text
queued -> processing -> completed
                    \-> failed
```

-   Cập nhật `started_at`, `finished_at`, `progress`.
-   Khi lỗi, lưu thông báo an toàn cho người dùng và log chi tiết ở
    server.
-   Không để job thất bại khiến dự án bị khóa.
-   Cho phép người dùng tạo một lần render mới.
-   Đặt giới hạn concurrency vì FFmpeg có thể dùng nhiều CPU/RAM.

Nếu dùng Solid Queue, xác nhận worker đang chạy trong development và
production. Không chạy render nặng trực tiếp trong request của
controller.

------------------------------------------------------------------------

## 12. Bảo mật, quyền riêng tư và dữ liệu

Vì chưa có Authentication, đây là điểm phải đặc biệt cẩn thận.

-   Không công khai danh sách mọi dự án nếu không cần.
-   Dùng token ngẫu nhiên khó đoán cho URL chia sẻ.
-   Có nút bật/tắt chia sẻ.
-   Cho phép thu hồi hoặc tạo token mới.
-   Không để ID tuần tự là cơ chế duy nhất để truy cập nội dung riêng
    tư.
-   Validate loại file và kích thước ở server.
-   Giới hạn số ảnh/dự án và request upload.
-   Không ghi API key, URL có token hoặc nội dung riêng tư vào log.
-   Thiết lập giới hạn upload và timeout.
-   Xóa file đính kèm khi người dùng xóa ảnh/dự án theo đúng policy.
-   Dùng HTTPS khi deploy.
-   Đảm bảo trang chia sẻ không chứa nút quản trị.
-   Nếu mở website công khai, thêm một lớp bảo vệ cho dashboard quản trị
    hoặc giới hạn truy cập.

**Khuyến nghị:** Trước mắt chỉ dùng cá nhân hoặc nhóm thử nghiệm nhỏ.
Không nên mở dashboard không có authentication cho Internet công khai.

------------------------------------------------------------------------

## 13. Kiểm thử

### Model tests

-   Memory yêu cầu title.
-   MemoryPhoto chỉ chấp nhận loại ảnh hợp lệ và giới hạn dung lượng.
-   Story lưu JSON hợp lệ.
-   VideoRender chỉ nhận trạng thái hợp lệ.
-   Share token unique và không đoán được.

### Controller/integration tests

-   Tạo, sửa, xóa Memory.
-   Upload nhiều ảnh.
-   Cập nhật thứ tự ảnh.
-   Sinh Story và xử lý API lỗi.
-   Tạo VideoRender.
-   Trang chia sẻ chỉ hiển thị khi token hợp lệ và sharing bật.

### Service tests

-   Story generator parse JSON đúng.
-   Xử lý JSON lỗi, timeout và rate limit.
-   TimelineBuilder gán ảnh hợp lệ.
-   Renderer xử lý thiếu ảnh, thiếu nhạc, FFmpeg lỗi.
-   Output MP4 tồn tại và ffprobe đọc được metadata.

### Manual acceptance test

1.  Tạo kỷ niệm "6 năm ngày cưới".
2.  Upload 10--30 ảnh.
3.  Sắp xếp lại ảnh và reload trang để xác nhận thứ tự được lưu.
4.  Nhập tâm sự.
5.  Sinh lời dẫn AI.
6.  Sửa và lưu lời dẫn.
7.  Chọn template.
8.  Tạo video.
9.  Chờ job hoàn tất.
10. Xem video, tải MP4.
11. Bật link chia sẻ và mở trong cửa sổ riêng tư.
12. Tắt chia sẻ và xác nhận link không còn xem được.

------------------------------------------------------------------------

## 14. Deployment

### Phương án MVP đơn giản

-   Một máy chủ chạy Rails web và Solid Queue worker.
-   PostgreSQL.
-   Active Storage local trong giai đoạn thử nghiệm hoặc S3 khi cần lưu
    bền vững.
-   FFmpeg được cài trên môi trường worker.
-   HTTPS và domain nếu cần chia sẻ bên ngoài.

Nếu dùng Docker, đảm bảo image worker có FFmpeg. Nếu chạy Rails trực
tiếp trên máy chủ, cài FFmpeg trên hệ điều hành và xác nhận user chạy
Rails có quyền tạo file tạm.

### Checklist production

-   [ ] `RAILS_MASTER_KEY`/credentials được cấu hình an toàn.
-   [ ] API key LLM được cấu hình server-side.
-   [ ] Database được backup.
-   [ ] Storage tồn tại bền vững; không lưu file duy nhất trên ephemeral
    filesystem.
-   [ ] Solid Queue worker hoạt động.
-   [ ] FFmpeg và ffprobe hoạt động.
-   [ ] HTTPS được bật.
-   [ ] Log không chứa secret.
-   [ ] Giới hạn upload và thời gian render.
-   [ ] Thử tạo và tải video sau deploy.
-   [ ] Có cách theo dõi job lỗi.

------------------------------------------------------------------------

## 15. Kế hoạch thực thi theo ngày: 20--25/10/2026

### Ngày 20/10 --- Rails foundation

-   [ ] Khởi tạo project.
-   [ ] Cấu hình PostgreSQL.
-   [ ] Cài Active Storage.
-   [ ] Tạo model và migration.
-   [ ] Làm dashboard và form tạo Memory.
-   [ ] Cài FFmpeg và xác nhận lệnh chạy thành công.

**Kết quả:** Tạo được dự án kỷ niệm và lưu dữ liệu.

### Ngày 21/10 --- Upload và quản lý ảnh

-   [ ] Upload nhiều ảnh.
-   [ ] Preview ảnh bằng StimulusJS.
-   [ ] Xóa ảnh.
-   [ ] Sắp xếp ảnh và lưu `position`.
-   [ ] Thêm caption.
-   [ ] Giới hạn dung lượng/số ảnh.

**Kết quả:** Quản lý được album ảnh.

### Ngày 22/10 --- AI story

-   [ ] Tạo LLM service.
-   [ ] Viết prompt và schema JSON.
-   [ ] Sinh title, subtitle, scenes và ending.
-   [ ] Lưu Story.
-   [ ] Cho phép sửa và lưu nội dung.
-   [ ] Xử lý timeout và response lỗi.

**Kết quả:** Có kịch bản video có thể chỉnh sửa.

### Ngày 23/10 --- FFmpeg renderer

-   [ ] Tạo TimelineBuilder.
-   [ ] Render ảnh thành video.
-   [ ] Thêm title và lời kết.
-   [ ] Thêm nhạc nền có quyền sử dụng.
-   [ ] Tạo ít nhất một template hoàn chỉnh.
-   [ ] Render bằng background job.
-   [ ] Kiểm tra output bằng ffprobe.

**Kết quả:** Có thể tạo file MP4 thật. Nếu chậm tiến độ, ưu tiên một
template hoạt động ổn định trước.

### Ngày 24/10 --- UI, sharing và deploy

-   [ ] Trang xem video.
-   [ ] Nút tải MP4.
-   [ ] Trang chia sẻ dùng token ngẫu nhiên.
-   [ ] Bật/tắt chia sẻ.
-   [ ] Kiểm thử luồng từ đầu đến cuối.
-   [ ] Deploy nếu cần.
-   [ ] Kiểm tra storage và worker.

**Kết quả:** Người khác có thể xem video qua link.

### Ngày 25/10 --- Buffer và release

-   [ ] Sửa lỗi nghiêm trọng.
-   [ ] Kiểm thử ảnh portrait/landscape.
-   [ ] Kiểm tra âm lượng và thời lượng.
-   [ ] Thử tạo lại video sau khi sửa Story.
-   [ ] Kiểm tra quyền riêng tư.
-   [ ] Chốt bản MVP.

**Kết quả:** Bản MVP có thể sử dụng được.

------------------------------------------------------------------------

## 16. Thứ tự ưu tiên khi bị trễ deadline

Nếu thời gian không đủ, cắt theo thứ tự sau:

1.  Chỉ giữ một template video.
2.  Chưa làm kéo-thả ảnh; dùng trường position hoặc nút lên/xuống.
3.  Chưa làm dashboard đẹp; tập trung luồng tạo video.
4.  Chưa deploy nếu deadline chỉ yêu cầu demo local.
5.  Dùng nhạc nền cố định có quyền sử dụng.
6.  Giới hạn video 10--15 ảnh và khoảng 30--45 giây.
7.  Không làm AI voice-over, AI phân tích ảnh hay thanh toán.

**Không cắt:** Luồng upload ảnh, sinh nội dung, render MP4 và kiểm tra
output. Đây là giá trị cốt lõi của sản phẩm.

------------------------------------------------------------------------

## 17. Cấu trúc thư mục đề xuất

``` text
app/
├── controllers/
│   ├── memories_controller.rb
│   ├── memory_photos_controller.rb
│   ├── memory_stories_controller.rb
│   ├── video_renders_controller.rb
│   └── shared_memories_controller.rb
├── models/
│   ├── memory.rb
│   ├── memory_photo.rb
│   ├── story.rb
│   ├── video_template.rb
│   └── video_render.rb
├── services/
│   ├── stories/
│   │   └── generator.rb
│   └── videos/
│       ├── timeline_builder.rb
│       └── renderer.rb
├── jobs/
│   ├── generate_story_job.rb
│   ├── render_video_job.rb
│   └── cleanup_temporary_files_job.rb
├── views/
│   ├── memories/
│   ├── memory_photos/
│   ├── memory_stories/
│   ├── video_renders/
│   └── shared_memories/
└── javascript/
    └── controllers/
        ├── photo_upload_controller.js
        ├── photo_sort_controller.js
        ├── story_form_controller.js
        └── video_render_controller.js
```

------------------------------------------------------------------------

## 18. Lệnh kiểm tra thường dùng

``` bash
# Chạy server
bin/rails server

# Chạy test
bin/rails test

# Kiểm tra routes
bin/rails routes

# Chạy migrations
bin/rails db:migrate

# Kiểm tra FFmpeg
ffmpeg -version
ffprobe -version

# Tạo một file video test đơn giản
ffmpeg -f lavfi -i color=c=black:s=1280x720:d=2 \
  -c:v libx264 -pix_fmt yuv420p /tmp/anniversary-test.mp4

# Kiểm tra metadata video
ffprobe -v error -show_format -show_streams /tmp/anniversary-test.mp4
```

------------------------------------------------------------------------

## 19. Rủi ro chính

  -----------------------------------------------------------------------
  Rủi ro                              Cách giảm thiểu
  ----------------------------------- -----------------------------------
  FFmpeg khó xử lý nhiều tỷ lệ ảnh    Chuẩn hóa ảnh và chỉ hỗ trợ một tỷ
                                      lệ đầu ra trước

  Render quá lâu                      Giới hạn số ảnh/thời lượng, dùng
                                      background job

  AI trả JSON không hợp lệ            Validate schema, retry có giới hạn,
                                      cho phép sửa thủ công

  API AI tốn phí                      Giới hạn số lần tạo, độ dài prompt
                                      và output

  Mất file khi deploy                 Dùng storage bền vững như S3

  Link chia sẻ làm lộ ảnh             Token khó đoán, bật/tắt share,
                                      không liệt kê project công khai

  Deadline quá ngắn                   Làm một template hoàn chỉnh trước,
                                      thêm template sau
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 20. Định nghĩa hoàn thành MVP

MVP được xem là hoàn thành khi:

-   [ ] Ứng dụng chạy ổn định.
-   [ ] Tạo được một dự án kỷ niệm.
-   [ ] Upload và quản lý ảnh.
-   [ ] AI sinh nội dung tiếng Việt có thể chỉnh sửa.
-   [ ] Render được MP4 bằng FFmpeg.
-   [ ] Video có ảnh, chữ và nhạc nền.
-   [ ] Người dùng xem và tải được video.
-   [ ] Link chia sẻ có thể bật/tắt.
-   [ ] Lỗi AI/FFmpeg không làm mất dữ liệu dự án.
-   [ ] Không cần Authentication trong phạm vi cá nhân hiện tại.

**Khuyến nghị cuối:** Bắt đầu bằng một template, 10--15 ảnh, video
30--45 giây và một LLM API. Làm cho luồng end-to-end hoạt động trước;
sau đó mới mở rộng lên 30 ảnh, nhiều template và giao diện đẹp hơn.
