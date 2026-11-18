ALTER TABLE public.chat_attachments DROP CONSTRAINT IF EXISTS reach_chat_name_safe;
ALTER TABLE public.chat_attachments ADD CONSTRAINT reach_chat_name_safe CHECK(
 length(file_name) BETWEEN 1 AND 180
 AND strpos(file_name,'/') = 0
 AND strpos(file_name,chr(92)) = 0
 AND lower(file_name) ~ '[.](pdf|txt|csv|doc|docx|xls|xlsx|ppt|pptx|jpg|jpeg|png|webp|gif|mp3|m4a|aac|ogg|wav|mp4|mov|webm)$'
);
