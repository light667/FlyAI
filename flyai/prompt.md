# Fly AI — Full Development Specification

## Role

You are a Senior Flutter Engineer, Software Architect, Product Designer, Firebase Expert, Supabase Expert, and AI Integration Specialist.

Your mission is to build **Fly AI**, a production-ready cross-platform application using Flutter.

The application must be scalable, maintainable, performant, and follow modern software engineering best practices.

Do not generate prototype code.

Always generate production-grade code.

Use Clean Architecture, SOLID principles, Feature-First Architecture, Repository Pattern, Dependency Injection, and Riverpod.

---

# Project Overview

## What is Fly AI?

Fly AI is an AI-powered scholarship matching platform.

The concept is:

> Tinder for Scholarships + AI to Win Them.

Students create a profile, and Fly AI automatically matches them with scholarships based on eligibility, academic background, language skills, preferred countries, and study goals.

Instead of browsing endless lists, students swipe through personalized scholarship opportunities.

When a scholarship is accepted, Fly AI helps the student complete the application process using AI assistance.

---

# Product Vision

Our goal is to make scholarship discovery and application as simple as:

**Swipe → Match → Apply → Fly**

Fly AI should help African students access global academic opportunities through intelligent matching and AI-powered guidance.

---

# Technology Stack

## Frontend

- Flutter 3+
- Dart

## Authentication

- Firebase Authentication

Authentication providers:

- Email / Password
- Google Sign-In
- Apple Sign-In
- Password Reset

Firebase Auth is used ONLY for authentication.

---

## Database

- Supabase PostgreSQL

Supabase will be used for:

- User profile storage
- Scholarships
- Swipes
- Matches
- Applications
- AI conversations
- Analytics

---

## Storage

- Supabase Storage

Used for:

- CV uploads
- Profile photos
- Application documents

---

## AI

- Gemini API or Mistral API or Groq API

Future support:

- Claude
- Gemini

---

## State Management

- Riverpod

---

## Routing

- GoRouter

---

## Local Database

- Hive

Used for:

- Offline caching
- User preferences
- Temporary scholarship storage

---

# Architecture

Use Feature-First Clean Architecture.

```text
lib/

core/
  constants/
  theme/
  router/
  services/
  network/
  widgets/
  utils/

features/

  onboarding/
  auth/
  profile/
  scholarships/
  swipe/
  dashboard/
  ai_assistant/
  applications/
  settings/

shared/
```

---

# Branding

## App Name

Fly AI

## Tagline

Swipe. Match. Apply. Fly.

---

# Design System

## Colors

Primary:

#2563EB

Secondary:

#F59E0B

Background:

#0F172A

Card:

#1E293B

Text Primary:

#FFFFFF

Text Secondary:

#CBD5E1

Success:

#22C55E

Error:

#EF4444

---

## Typography

Font Family:

Inter

---

## Border Radius

16px

---

## UI Style

Modern

Premium

Mobile-first

Glassmorphism-inspired

Smooth animations

Inspired by:

- Tinder
- Duolingo
- Revolut
- Airbnb
- LinkedIn

---

# User Flow

---

## Splash Screen

Display Fly AI logo.

Animate logo.

Duration:

2 seconds

Then automatically navigate.

---

# Onboarding

## Page 1

Title:

Find Your Next Opportunity

Description:

Discover scholarships tailored to your profile and ambitions.

---

## Page 2

Title:

AI Finds Your Best Matches

Description:

Swipe through opportunities and receive personalized recommendations powered by AI.

---

## Page 3

Title:

Build Your Future With Confidence

Description:

Get AI assistance throughout your scholarship application journey.

---

Buttons:

Skip

Next

Get Started

---

# Authentication

Firebase Authentication

Features:

- Sign Up
- Login
- Forgot Password
- Google Sign In
- Apple Sign In
- Logout

After authentication:

Check profile completion.

If profile does not exist:

Navigate to Profile Setup.

---

# Student Profile

Collect:

- Full Name
- Country
- Nationality
- Date of Birth
- Education Level
- University
- Field of Study
- GPA
- English Level
- French Level
- Preferred Countries
- Preferred Study Fields
- Academic Goals
- CV Upload
- Profile Photo

Store inside Supabase.

---

# Scholarship Matching Engine

The system must calculate a compatibility score between:

Student Profile

and

Scholarship

Criteria include:

- Education Level
- Study Field
- Language Requirements
- Destination Country
- Nationality Eligibility
- Funding Type

Generate:

Compatibility Score

Range:

0 - 100

---

# Swipe Experience

Main feature of Fly AI.

Tinder-style interface.

Each scholarship card displays:

- Scholarship Name
- University
- Country
- Degree Level
- Funding Type
- Deadline
- Compatibility Score
- Scholarship Image

Actions:

Swipe Left:

Not Interested

Swipe Right:

Interested

Swipe Up:

Priority Scholarship

Support gesture-based interactions.

Include smooth animations.

---

# Dashboard

Display:

## Statistics

- Total Matches
- Saved Scholarships
- Active Applications
- Average Compatibility

---

## My Scholarships

Liked Scholarships

---

## Priority Scholarships

Super Likes

---

## Recent Activity

User activity timeline

---

# Scholarship Details Page

Display:

- Description
- University
- Country
- Funding Information
- Eligibility Criteria
- Required Documents
- Deadline
- Application Link
- Compatibility Breakdown

Button:

Start Application

---

# AI Assistant

Name:

Fly Assistant

Capabilities:

- Scholarship Guidance
- CV Review
- Motivation Letter Generation
- SOP Review
- Application Strategy
- Interview Preparation
- Scholarship Questions

Store conversation history.

---

# Application Management

For every scholarship:

Generate a checklist.

Example:

- CV
- Passport
- Degree Certificate
- Academic Transcript
- Recommendation Letter
- Motivation Letter

Track completion percentage.

Progress:

0% → 100%

---

# Database Schema

## users

Managed by Firebase Authentication.

Use Firebase UID as primary user identifier.

---

## profiles

```sql
id UUID PRIMARY KEY

firebase_uid TEXT UNIQUE

full_name TEXT

country TEXT

nationality TEXT

birth_date DATE

education_level TEXT

field_of_study TEXT

university TEXT

gpa NUMERIC

english_level TEXT

french_level TEXT

target_countries JSONB

target_fields JSONB

academic_goals TEXT

cv_url TEXT

photo_url TEXT

created_at TIMESTAMP
```

---

## scholarships

```sql
id UUID PRIMARY KEY

title TEXT

provider TEXT

university TEXT

country TEXT

description TEXT

funding_type TEXT

degree_level TEXT

fields JSONB

eligibility JSONB

requirements JSONB

language_requirements JSONB

deadline DATE

application_url TEXT

image_url TEXT

source TEXT

active BOOLEAN

created_at TIMESTAMP
```

---

## swipes

```sql
id UUID PRIMARY KEY

firebase_uid TEXT

scholarship_id UUID

action TEXT
```

Values:

- like
- dislike
- super_like

---

## matches

```sql
id UUID PRIMARY KEY

firebase_uid TEXT

scholarship_id UUID

compatibility_score INTEGER
```

---

## applications

```sql
id UUID PRIMARY KEY

firebase_uid TEXT

scholarship_id UUID

status TEXT

progress INTEGER

created_at TIMESTAMP
```

---

## chat_sessions

```sql
id UUID PRIMARY KEY

firebase_uid TEXT

created_at TIMESTAMP
```

---

## chat_messages

```sql
id UUID PRIMARY KEY

session_id UUID

role TEXT

content TEXT

created_at TIMESTAMP
```

---

# Existing Data Sources

Fly AI already has scrapers for:

- Scholarship Positions
- Greatyop
- Opportunities For Africans

The architecture must support:

- Scholarship imports
- Data synchronization
- Deduplication
- Future AI enrichment

---

# Performance Requirements

Must support:

- Android
- iOS
- Web
- Desktop

Requirements:

- Lazy Loading
- Pagination
- Caching
- Offline Support
- Fast Startup
- Smooth Animations

---

# Code Quality Requirements

Every feature must include:

- Models
- Entities
- Repositories
- Services
- Riverpod Providers
- UI Screens
- Reusable Widgets
- Error Handling
- Unit Tests

Never generate temporary code.

Always produce scalable production-ready architecture.

---

# Development Order

Phase 1

- Project Initialization
- Theme System
- Routing
- Firebase Setup
- Authentication

Phase 2

- Supabase Setup
- Database Models
- Profile Setup Flow

Phase 3

- Scholarship Retrieval
- Matching Engine

Phase 4

- Swipe Interface

Phase 5

- Dashboard

Phase 6

- Scholarship Details

Phase 7

- AI Assistant

Phase 8

- Application Tracking

Phase 9

- Analytics
- Optimization
- Testing
- Production Release

---

Build Fly AI as a world-class EdTech product capable of serving thousands of students and becoming the leading AI-powered scholarship matching platform in Africa.
