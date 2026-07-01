-- ==========================================
-- Fly AI Database Schema Setup Script
-- Paste this in your Supabase SQL Editor and run it
-- ==========================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT UNIQUE NOT NULL,
  full_name TEXT,
  country TEXT,
  nationality TEXT,
  birth_date DATE,
  education_level TEXT,
  field_of_study TEXT,
  university TEXT,
  gpa NUMERIC,
  english_level TEXT,
  french_level TEXT,
  target_countries JSONB DEFAULT '[]',
  target_fields JSONB DEFAULT '[]',
  academic_goals TEXT,
  cv_url TEXT,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Scholarships Table
CREATE TABLE IF NOT EXISTS scholarships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  provider TEXT,
  university TEXT,
  country TEXT NOT NULL,
  description TEXT,
  funding_type TEXT NOT NULL,
  degree_level TEXT NOT NULL,
  fields JSONB DEFAULT '[]',
  eligibility JSONB DEFAULT '{}',
  requirements JSONB DEFAULT '[]',
  language_requirements JSONB DEFAULT '{}',
  deadline DATE,
  application_url TEXT,
  image_url TEXT,
  source TEXT,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Swipes Table
CREATE TABLE IF NOT EXISTS swipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  scholarship_id UUID REFERENCES scholarships(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('like', 'dislike', 'super_like')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Matches Table
CREATE TABLE IF NOT EXISTS matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  scholarship_id UUID REFERENCES scholarships(id) ON DELETE CASCADE,
  compatibility_score INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Applications Table
CREATE TABLE IF NOT EXISTS applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  scholarship_id UUID REFERENCES scholarships(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'draft',
  progress INTEGER DEFAULT 0,
  checklist JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Chat Sessions Table
CREATE TABLE IF NOT EXISTS chat_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Community Posts Table
CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT NOT NULL,
  author_name TEXT NOT NULL,
  author_photo TEXT,
  content TEXT NOT NULL,
  tags JSONB DEFAULT '[]',
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. Post Likes Table
CREATE TABLE IF NOT EXISTS post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  firebase_uid TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (post_id, firebase_uid)
);

-- 10. Direct Messages Table
CREATE TABLE IF NOT EXISTS direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_uid TEXT NOT NULL,
  receiver_uid TEXT NOT NULL,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Likes Count RPC Helpers
CREATE OR REPLACE FUNCTION increment_likes(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE posts
  SET likes_count = likes_count + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION decrement_likes(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE posts
  SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- Disable Row Level Security (RLS) for all tables to allow public development testing
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE scholarships DISABLE ROW LEVEL SECURITY;
ALTER TABLE swipes DISABLE ROW LEVEL SECURITY;
ALTER TABLE matches DISABLE ROW LEVEL SECURITY;
ALTER TABLE applications DISABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE posts DISABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE direct_messages DISABLE ROW LEVEL SECURITY;

-- Insert Mock Scholarship Opportunities for Discover Swiper Testing
INSERT INTO scholarships (title, provider, university, country, description, funding_type, degree_level, fields, eligibility, requirements, language_requirements, deadline, image_url, active)
VALUES 
('Master of Computer Science Excellence Scholarship', 'DAAD', 'Technical University of Munich', 'Germany', 'A fully funded master scholarship for top-tier African developers to specialize in advanced AI and cloud systems engineering.', 'Fully Funded', 'Master''s Degree', '["Computer Science", "Software Engineering", "Artificial Intelligence & Data Science"]', '{"min_gpa": 3.0, "nationalities": []}', '["CV", "Academic Transcript", "Motivation Letter", "Degree Certificate"]', '{"english": "advanced"}', '2026-12-01', 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97', true),
('African Leaders Undergraduate Award', 'Mastercard Foundation', 'McGill University', 'Canada', 'Comprehensive scholarship covering full tuition, living stipends, healthcare, and airfare for outstanding young African undergraduates.', 'Fully Funded', 'Bachelor''s Degree', '["Computer Science", "Business Administration", "Economics", "Public Health"]', '{"min_gpa": 3.2, "continent": "africa"}', '["Passport", "CV", "Recommendation Letter", "Academic Transcript"]', '{"english": "intermediate"}', '2026-11-15', 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1', true),
('Eiffel Excellence Program for Developing Countries', 'French Ministry of Foreign Affairs', 'Sorbonne University', 'France', 'Prestigious program designed to train future decision-makers in public and private sectors in engineering, economics, and law.', 'Fully Funded', 'Master''s Degree', '["Mechanical Engineering", "Law & Jurisprudence", "Finance & Banking", "Political Science"]', '{"min_gpa": 3.0, "nationalities": []}', '["CV", "Motivation Letter", "Degree Certificate", "Language Certificate"]', '{"french": "advanced"}', '2026-10-30', 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34', true);

