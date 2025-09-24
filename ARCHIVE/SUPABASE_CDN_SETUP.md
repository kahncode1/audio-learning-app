# Supabase CDN Setup Guide

## 📅 Implementation Date: September 18, 2025

## ✅ Current Status

### Completed
1. **Storage Buckets Created** ✅
   - `course-audio` - For MP3 files (50MB limit)
   - `course-content` - For JSON content (10MB limit)
   - `course-timing` - For JSON timing data (5MB limit)

2. **RLS Policies Configured** ✅
   - Public read access enabled for all buckets
   - Public insert/update enabled for testing
   - Production note: Remove public insert/update later

3. **Database URLs Updated** ✅
   - Learning object `63ad7b78-0970-4265-a4fe-51f3fee39d5f` configured with CDN URLs
   - URLs follow pattern: `https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/[bucket]/[path]`

## 📁 File Structure

```
storage/
├── course-audio/
│   └── INS-101/
│       └── 63ad7b78-0970-4265-a4fe-51f3fee39d5f/
│           └── audio.mp3
├── course-content/
│   └── INS-101/
│       └── 63ad7b78-0970-4265-a4fe-51f3fee39d5f/
│           └── content.json
└── course-timing/
    └── INS-101/
        └── 63ad7b78-0970-4265-a4fe-51f3fee39d5f/
            └── timing.json
```

## 🚀 Manual Upload Instructions

Since we're using mock authentication temporarily, you need to manually upload files through the Supabase Dashboard:

### Step 1: Access Supabase Dashboard
1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/cmjdciktvfxiyapdseqn)
2. Navigate to Storage → Buckets

### Step 2: Upload Files
For each bucket, upload the corresponding files:

#### Course Audio Bucket
1. Click on `course-audio` bucket
2. Create folder structure: `INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/`
3. Upload: `assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/audio.mp3`

#### Course Content Bucket
1. Click on `course-content` bucket
2. Create folder structure: `INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/`
3. Upload: `assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/content.json`

#### Course Timing Bucket
1. Click on `course-timing` bucket
2. Create folder structure: `INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/`
3. Upload: `assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/timing.json`

## 📍 CDN URLs

Once uploaded, the files will be accessible at:

- **Audio**: `https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-audio/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/audio.mp3`
- **Content**: `https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-content/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/content.json`
- **Timing**: `https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-timing/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/timing.json`

## 🧪 Testing the CDN

### Test Download Service
```dart
// The CourseDownloadService will automatically fetch CDN URLs from database
final service = await CourseDownloadService.getInstance();
await service.downloadCourse('INS-101', [learningObject]);
```

### Test Direct Access
```bash
# Test audio URL
curl -I https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-audio/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/audio.mp3

# Test content URL
curl https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-content/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/content.json

# Test timing URL
curl https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-timing/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f/timing.json
```

## 💰 CDN Benefits

### Performance
- **Global Edge Network**: Files cached at edge locations worldwide
- **Automatic Caching**: 30-day cache control headers
- **Smart CDN** (Pro Plan): Intelligent cache invalidation
- **Direct Public URLs**: No authentication overhead

### Cost Optimization
- **Cached Egress**: $0.03/GB (3x cheaper than uncached)
- **Uncached Egress**: $0.09/GB
- **Free Tier**: 5GB cached + 5GB uncached per month
- **Pro Plan**: 250GB cached + 250GB uncached per month

### Architecture Benefits
- **100% Cost Reduction**: No TTS API calls
- **Offline Capability**: Download once, play offline
- **Simplified Codebase**: Remove complex streaming logic
- **Instant Playback**: No generation latency

## 🔧 Programmatic Upload (When Auth Ready)

Once real authentication is implemented, use these scripts:

### Dart Upload Script
```dart
// scripts/upload_test_content.dart
// Already created - will work once auth is configured
```

### Bash Upload Script
```bash
# scripts/upload_to_supabase_cdn.sh
# Already created - requires service role key
```

## 📊 Monitoring

### Check Storage Usage
```sql
-- Check uploaded files
SELECT
  bucket_id,
  name,
  metadata->>'size' as size_bytes,
  metadata->>'mimetype' as mime_type,
  created_at
FROM storage.objects
WHERE bucket_id IN ('course-audio', 'course-content', 'course-timing')
ORDER BY created_at DESC;
```

### Check Download Progress
```sql
-- Monitor download progress
SELECT
  lo.title,
  lo.audio_url,
  lo.download_status,
  dp.progress_percentage,
  dp.bytes_downloaded,
  dp.completed_at
FROM learning_objects lo
LEFT JOIN download_progress dp ON lo.id = dp.learning_object_id
WHERE lo.audio_url IS NOT NULL;
```

## 🚨 Important Notes

1. **Mock Auth Limitation**: Currently using mock authentication, so API uploads require manual intervention
2. **Manual Upload Required**: Use Supabase Dashboard to upload files until auth is ready
3. **URLs Already Set**: Database already has CDN URLs configured, just need files uploaded
4. **Public Buckets**: All buckets are public for optimal CDN performance
5. **Test Content Ready**: All test files are in `assets/test_content/learning_objects/`

## ✅ Next Steps

1. ✅ Storage buckets created
2. ✅ Database URLs configured
3. ⏳ **Manual file upload through Dashboard** (Required)
4. ⏳ Test download flow with CourseDownloadService
5. ⏳ Verify offline playback works
6. ⏳ Remove public insert/update policies in production

## 🎯 Success Criteria

- [ ] Files accessible via CDN URLs
- [ ] CourseDownloadService successfully downloads files
- [ ] LocalContentService reads downloaded files
- [ ] Audio plays from downloaded content
- [ ] Word timing synchronization works

## 📚 Related Documentation

- `DOWNLOAD_ARCHITECTURE_PLAN.md` - Overall architecture design
- `PHASE_3_COMPLETION_SUMMARY.md` - Database migration details
- `mock-auth/MOCK_AUTH_USAGE_GUIDE.md` - Authentication context
- `lib/services/course_download_service.dart` - Download service implementation