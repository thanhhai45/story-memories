# Anniversary Memories

Website cá nhân biến ảnh và vài dòng tâm sự thành **video kỷ niệm MP4**: AI gợi ý tiêu đề, lời dẫn từng chương và lời kết; FFmpeg ghép ảnh, chữ, chuyển cảnh và nhạc nền theo template cố định.

Stack: **Rails 8 (MVC, ERB) · Hotwire (Turbo + Stimulus) · importmap · Tailwind CSS v4 · PostgreSQL · Active Storage · Solid Queue · FFmpeg · Anthropic API**. Phát triển hoàn toàn trong **Docker**, triển khai bằng **Kamal 2**.

Kế hoạch gốc: [`docs/anniversary_memories_mvp_plan.md`](docs/anniversary_memories_mvp_plan.md). Khung hình mẫu của hai template: `docs/preview-*.jpg`.

---

## Chạy trên máy (chỉ cần Docker)

```bash
cd ~/Desktop/projects/anniversary_memories
cp .env.example .env        # tùy chọn: điền ANTHROPIC_API_KEY
make up                     # hoặc: docker compose up --build
```

Mở <http://localhost:3000>. Lần đầu mất vài phút vì service `setup` sẽ:

1. `bundle install` vào volume `bundle` và tạo `Gemfile.lock` (khóa cho cả `x86_64-linux` và `aarch64-linux`).
2. `db:prepare`: tạo database chính + database hàng đợi Solid Queue, chạy migration, seed các template video.
3. Build Tailwind CSS.

Sau đó các service `web` (Rails), `jobs` (Solid Queue: AI + FFmpeg) và `css` (Tailwind watch) chạy song song.

| Lệnh | Việc |
|---|---|
| `make up` / `make down` | Bật / tắt toàn bộ |
| `make logs` | Log web + jobs |
| `make console` | Rails console |
| `make test` | Toàn bộ test, gồm test dựng video thật bằng FFmpeg |
| `make db-reset` | Xóa và tạo lại database phát triển |
| `make lock` | Tạo lại `Gemfile.lock` |

**Không có API key vẫn chạy được trọn luồng**: nút “Tạo bản nháp lời dẫn” sẽ dựng kịch bản từ chính tâm sự của bạn (không gọi AI). Thêm `ANTHROPIC_API_KEY` vào `.env` rồi `docker compose up -d` để AI viết. Model mặc định `claude-sonnet-5-5`, đổi bằng `LLM_MODEL` (ví dụ `claude-haiku-5-5` cho rẻ/nhanh hơn).

## Luồng sử dụng

1. **Tạo kỷ niệm**: tên, dịp, ngày, người liên quan, phong cách, đôi dòng tâm sự.
2. **Ảnh**: kéo-thả nhiều ảnh (JPEG/PNG/WebP, ≤ 15 MB, tối đa 30 ảnh), xem trước, bỏ bớt, tải lên từng ảnh; kéo để sắp xếp (lưu ngay vào DB), chú thích, chọn ảnh bìa, xóa.
3. **Câu chuyện**: “Viết câu chuyện giúp tôi” → job nền gọi AI → sửa tiêu đề, phụ đề, từng chương (lời dẫn + số thứ tự ảnh), lời kết → “Lưu nội dung”. “Viết lại bằng AI” tạo phiên bản mới, bản cũ giữ nguyên cho tới khi bản mới xong.
4. **Video**: chọn template + nhạc (nghe thử ngay trên trang) → “Tạo video” → trang tiến độ tự cập nhật → xem và tải MP4.
5. **Chia sẻ**: bật link `/s/<token>`, sao chép, tạo link mới (thu hồi link cũ) hoặc tắt chia sẻ.

## Kiến trúc

```
app/
├── controllers/   memories, memory_photos, memory_stories, video_renders,
│                  memory_sharings, shared_memories (+ concerns/admin_authentication)
├── models/        Memory, MemoryPhoto, Story, VideoTemplate, VideoRender, MusicLibrary
├── services/
│   ├── llm/anthropic_client.rb      HTTP client phía server (timeout, rate limit)
│   ├── stories/                     prompt, generator, content (schema), fallback_writer
│   └── videos/                      timeline_builder, renderer, memory_renderer,
│                                    command (chạy ffmpeg an toàn), probe (ffprobe), text_layout
├── jobs/          GenerateStoryJob (queue ai), RenderVideoJob (queue video),
│                  CleanupTemporaryFilesJob (mỗi giờ)
└── javascript/controllers/  photo_upload, photo_sort (SortableJS), story_form,
                             status_poll, video_render, clipboard
```

Controller mỏng; nghiệp vụ nằm trong service. AI và FFmpeg luôn chạy trong job nền; giao diện theo dõi trạng thái bằng Turbo Frame + polling nhẹ (dừng khi xong hoặc lỗi). Mỗi lần dựng là một `VideoRender` riêng (`queued → processing → completed | failed`), lỗi không làm mất ảnh hay lời dẫn, và có thể dựng lại.

### Dựng video (FFmpeg)

`Videos::TimelineBuilder` chuyển JSON câu chuyện + thứ tự ảnh thành các phân đoạn: mở đầu → (chương → ảnh…)* → lời kết, tự co thời lượng mỗi ảnh để video ≤ ~95 giây. Ảnh không được gán vào chương nào sẽ tự vào chương cuối; vị trí sai/trùng bị bỏ qua.

`Videos::Renderer` với mỗi phân đoạn:
1. ghép **một khung tĩnh** ở độ phân giải gấp đôi (nền, ảnh, chữ — chữ đọc từ file qua `textfile=` + `expansion=none`);
2. biến thành clip có chuyển động (Ken Burns bằng `zoompan`);
3. nối các clip bằng `xfade`, thêm nhạc (`loudnorm`, fade in/out), xuất **H.264 + AAC, 1280×720, 30 fps, faststart**;
4. kiểm tra output bằng `ffprobe`.

| Template | Phong cách |
|---|---|
| `romantic_cinematic` | Nền tối từ chính ảnh làm mờ, ảnh giữ nguyên tỷ lệ, zoom/pan chậm, mờ dần, chữ Playfair Display |
| `photo_album` | Trang giấy album, ảnh viền trắng hơi nghiêng có bóng đổ, chú thích từng ảnh, chuyển trang trượt |

Cấu hình template nằm trong `VideoTemplate.configuration` (JSON): kích thước, fps, thời lượng, bảng màu, kiểu chuyển cảnh. Sửa `VideoTemplate::DEFAULTS` rồi chạy `bin/rails templates:sync`.

Font (Playfair Display, Be Vietnam Pro — giấy phép OFL, đủ dấu tiếng Việt) nằm trong `app/assets/fonts`, dùng chung cho giao diện và video.

### Nhạc nền

`public/music/` có 3 bản nhạc **do dự án tự tổng hợp bằng code** (`script/synthesize_music.py`), không vướng bản quyền: *Piano nhẹ nhàng*, *Ấm áp*, *Vui tươi*. Muốn thêm nhạc: chép file `.m4a`/`.mp3` **có giấy phép hợp lệ** vào `public/music/` và khai báo trong `app/models/music_library.rb`. Người dùng chỉ chọn theo key trong danh sách; không thể truyền đường dẫn tùy ý.

## Bảo mật và quyền riêng tư (khi chưa có đăng nhập)

- **Basic Auth** cho toàn bộ trang quản trị khi đặt `ADMIN_PASSWORD`. Ở production, nếu thiếu `ADMIN_PASSWORD` thì trang quản trị trả 503 (trừ khi cố ý đặt `ALLOW_OPEN_ADMIN=true`).
- Trang chia sẻ dùng **token ngẫu nhiên 32 ký tự** (không dùng ID tuần tự), chỉ hoạt động khi bật chia sẻ; có thể tạo token mới để thu hồi. Link file video trên trang chia sẻ **hết hạn sau 1 giờ**, nên tắt chia sẻ là thu hồi thật. Trang gửi `noindex`, `no-referrer`, `no-store`; không có nút sửa, không lộ lỗi hay prompt.
- Ảnh được kiểm tra ở server: loại file do Active Storage nhận diện **và** chữ ký nhị phân đầu file; giới hạn dung lượng và số lượng; rate limit cho upload, sinh AI và dựng video.
- FFmpeg luôn chạy bằng danh sách tham số (không qua shell), có timeout, chỉ dùng file nội bộ; không bao giờ nhận URL hay đường dẫn từ người dùng.
- Prompt đặt dữ liệu người dùng trong thẻ riêng và yêu cầu AI bỏ qua mọi “chỉ dẫn” bên trong; kết quả được validate theo schema, thử lại tối đa 1 lần.
- API key chỉ nằm trong biến môi trường phía server. Log lọc tham số nhạy cảm (tâm sự, chú thích, token…) và che token trong đường dẫn `/s/[FILTERED]`.
- Content Security Policy chỉ cho phép tài nguyên cùng origin.

## Triển khai bằng Kamal

Cần: một máy chủ Ubuntu có SSH bằng key, tên miền trỏ về IP máy chủ, tài khoản registry (Docker Hub hoặc GHCR). **Không cần cài Ruby** — `bin/kamal` chạy Kamal bằng image `ghcr.io/basecamp/kamal`.

```bash
cp .env.deploy.example .env.deploy
# điền DEPLOY_HOST, APP_DOMAIN, REGISTRY_USERNAME, KAMAL_REGISTRY_PASSWORD,
# SECRET_KEY_BASE (openssl rand -hex 64), POSTGRES_PASSWORD (openssl rand -hex 24),
# ADMIN_PASSWORD, ANTHROPIC_API_KEY
ssh-add ~/.ssh/id_ed25519   # Kamal dùng ssh-agent
git add -A && git commit -m "deploy"   # Kamal gắn tag image theo commit git

make deploy-setup           # lần đầu: cài Docker trên server, chạy Postgres, deploy
make deploy                 # các lần sau
make kamal ARGS="app logs -f"
make kamal ARGS="console"   # Rails console trên production
```

`config/deploy.yml` gồm:
- role `web` (Thruster + Puma, kamal-proxy tự cấp HTTPS Let's Encrypt);
- role `job` (`bin/jobs`, FFmpeg chạy tách khỏi web, giới hạn `VIDEO_RENDER_CONCURRENCY=1`);
- accessory `db` (PostgreSQL 16, chỉ mở cho localhost của máy chủ);
- volume `anniversary_memories_storage` cho ảnh và video, dùng chung giữa web và job.

Image production (`Dockerfile`) đã có `ffmpeg`, `ffprobe`, `libvips`. Lần deploy đầu `db:prepare` tự tạo 2 database, chạy migration và seed template; mỗi lần khởi động đều chạy `templates:sync` để thêm template mới.

**Lưu trữ**: mặc định lưu trên ổ đĩa máy chủ (volume). Muốn bền vững hơn hoặc chạy nhiều máy, đặt `ACTIVE_STORAGE_SERVICE=amazon` và các biến `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` (thêm `S3_ENDPOINT` cho Cloudflare R2/DigitalOcean Spaces).

**Sao lưu database**, ví dụ chạy cron trên máy chủ:
```bash
docker exec anniversary_memories-db pg_dump -U anniversary anniversary_memories_production | gzip > backup-$(date +%F).sql.gz
```

### Checklist production
- [ ] `SECRET_KEY_BASE`, `POSTGRES_PASSWORD`, `ADMIN_PASSWORD` đã đặt
- [ ] `ANTHROPIC_API_KEY` (nếu dùng AI)
- [ ] Tên miền trỏ đúng, HTTPS hoạt động
- [ ] Container `job` đang chạy: `make kamal ARGS="app details"`
- [ ] Tạo thử một kỷ niệm, dựng và tải video sau khi deploy
- [ ] Sao lưu database định kỳ; cân nhắc S3 cho file
- [ ] Theo dõi job lỗi: `make kamal ARGS="jobs-logs"` hoặc bảng `solid_queue_failed_executions`

## Đối chiếu với kế hoạch MVP

| Hạng mục | Trạng thái |
|---|---|
| Tạo/sửa/xóa dự án kỷ niệm | ✅ |
| Upload nhiều ảnh, xem trước, xóa, sắp xếp kéo-thả (lưu DB), caption, ảnh bìa | ✅ |
| Lời dẫn tiếng Việt bằng AI, sửa trước khi dựng, tạo lại | ✅ (kèm bản nháp không cần AI) |
| 2 template video | ✅ Romantic Cinematic, Photo Album |
| Ghép ảnh, chữ, nhạc, chuyển cảnh thành MP4, kiểm tra bằng ffprobe | ✅ |
| Trạng thái render, xem và tải video | ✅ |
| Trang chia sẻ bằng token, bật/tắt, thu hồi | ✅ |
| Chạy local bằng Docker, deploy bằng Kamal | ✅ (cấu hình sẵn) |
| Auth, thanh toán, AI video/voice, multi-tenant | Ngoài phạm vi MVP |

## Ghi chú

- Phần dựng video (timeline, FFmpeg, ffprobe, 2 template, chữ tiếng Việt, nhạc, xử lý lỗi/timeout) đã được chạy thật. Phần Rails được viết theo chuẩn Rails 8 và có bộ test đầy đủ, nhưng **lần `make up` đầu tiên là lần đầu app khởi động** — nếu gặp lỗi, chạy `make test` và `make logs` để xem chi tiết.
- Thời gian dựng ước tính 1–2 phút cho video ~60 giây trên máy chủ 1–2 vCPU.
- Render 1920×1080: đổi `width`/`height` trong cấu hình template (chậm hơn khoảng 2 lần).
