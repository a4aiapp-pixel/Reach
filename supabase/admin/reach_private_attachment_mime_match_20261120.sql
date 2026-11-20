-- Validate extension vs claimed upload content type. Prevents basic
-- mislabelled categories; does not inspect actual bytes or classify images.
BEGIN;
ALTER TABLE public.chat_attachments
 DROP CONSTRAINT IF EXISTS reach_attachment_mime_suffix_match;
ALTER TABLE public.chat_attachments
 ADD CONSTRAINT reach_attachment_mime_suffix_match CHECK (
  CASE lower(split_part(file_name,'.',
   array_length(string_to_array(file_name,'.'),1)))
   WHEN 'jpg' THEN mime_type='image/jpeg'
   WHEN 'jpeg' THEN mime_type='image/jpeg'
   WHEN 'png' THEN mime_type='image/png'
   WHEN 'webp' THEN mime_type='image/webp'
   WHEN 'gif' THEN mime_type='image/gif'
   WHEN 'mp3' THEN mime_type='audio/mpeg'
   WHEN 'm4a' THEN mime_type='audio/mp4'
   WHEN 'aac' THEN mime_type='audio/aac'
   WHEN 'ogg' THEN mime_type='audio/ogg'
   WHEN 'wav' THEN mime_type='audio/wav'
   WHEN 'mp4' THEN mime_type='video/mp4'
   WHEN 'mov' THEN mime_type='video/quicktime'
   WHEN 'webm' THEN mime_type='video/webm'
   WHEN 'pdf' THEN mime_type='application/pdf'
   WHEN 'txt' THEN mime_type='text/plain'
   WHEN 'csv' THEN mime_type='text/csv'
   WHEN 'doc' THEN mime_type='application/msword'
   WHEN 'docx' THEN mime_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document'
   WHEN 'xls' THEN mime_type='application/vnd.ms-excel'
   WHEN 'xlsx' THEN mime_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
   WHEN 'ppt' THEN mime_type='application/vnd.ms-powerpoint'
   WHEN 'pptx' THEN mime_type='application/vnd.openxmlformats-officedocument.presentationml.presentation'
   ELSE false END
 );
COMMIT;