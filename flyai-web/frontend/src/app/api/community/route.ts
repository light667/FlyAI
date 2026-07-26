import { NextRequest, NextResponse } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function GET(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const { searchParams } = new URL(req.url);
    const type = searchParams.get("type") || "posts";
    const userId = searchParams.get("userId");

    if (type === "direct_messages") {
      const otherId = searchParams.get("otherId");
      if (!userId || !otherId) {
        return NextResponse.json({ error: "userId et otherId requis" }, { status: 400 });
      }

      const { data: dms, error } = await supabase
        .from("direct_messages")
        .select("*")
        .or(`and(sender_uid.eq.${userId},receiver_uid.eq.${otherId}),and(sender_uid.eq.${otherId},receiver_uid.eq.${userId})`)
        .order("created_at", { ascending: true });

      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
      return NextResponse.json({ data: dms || [] });
    }

    // Default: fetch community posts
    const { data: posts, error } = await supabase
      .from("posts")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(30);

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    // Check user likes if userId provided
    let userLikedPostIds = new Set<string>();
    if (userId) {
      const { data: likes } = await supabase
        .from("post_likes")
        .select("post_id")
        .eq("firebase_uid", userId);

      if (likes) {
        userLikedPostIds = new Set(likes.map((l) => l.post_id));
      }
    }

    const formattedPosts = (posts || []).map((p) => ({
      id: p.id,
      userId: p.firebase_uid,
      authorName: p.author_name,
      authorAvatar: p.author_photo,
      content: p.content,
      tags: p.tags || [],
      likesCount: p.likes_count || 0,
      commentsCount: p.comments_count || 0,
      userHasLiked: userLikedPostIds.has(p.id),
      createdAt: p.created_at,
    }));

    return NextResponse.json({ data: formattedPosts });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const supabase = getSupabaseServerClient();
    const body = await req.json();
    const { action } = body;

    if (action === "create_post") {
      const { userId, authorName, authorAvatar, content, tags } = body;
      if (!userId || !content) {
        return NextResponse.json({ error: "userId et content requis" }, { status: 400 });
      }

      const { data: newPost, error } = await supabase
        .from("posts")
        .insert({
          firebase_uid: userId,
          author_name: authorName || "Étudiant FlyAI",
          author_photo: authorAvatar || "",
          content,
          tags: tags || ["Général"],
          likes_count: 0,
          comments_count: 0,
        })
        .select()
        .single();

      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
      return NextResponse.json({ success: true, data: newPost });
    }

    if (action === "like_post") {
      const { userId, postId } = body;
      if (!userId || !postId) {
        return NextResponse.json({ error: "userId et postId requis" }, { status: 400 });
      }

      // Toggle like
      const { data: existingLike } = await supabase
        .from("post_likes")
        .select("id")
        .eq("firebase_uid", userId)
        .eq("post_id", postId)
        .maybeSingle();

      if (existingLike) {
        await supabase.from("post_likes").delete().eq("id", existingLike.id);
        await supabase.rpc("decrement_post_likes", { p_post_id: postId }).catch(async () => {
          const { data: p } = await supabase.from("posts").select("likes_count").eq("id", postId).single();
          if (p) await supabase.from("posts").update({ likes_count: Math.max(0, p.likes_count - 1) }).eq("id", postId);
        });
        return NextResponse.json({ success: true, liked: false });
      } else {
        await supabase.from("post_likes").insert({ firebase_uid: userId, post_id: postId });
        const { data: p } = await supabase.from("posts").select("likes_count").eq("id", postId).single();
        if (p) await supabase.from("posts").update({ likes_count: (p.likes_count || 0) + 1 }).eq("id", postId);
        return NextResponse.json({ success: true, liked: true });
      }
    }

    if (action === "send_dm") {
      const { senderId, receiverId, content } = body;
      if (!senderId || !receiverId || !content) {
        return NextResponse.json({ error: "senderId, receiverId et content requis" }, { status: 400 });
      }

      const { data: dm, error } = await supabase
        .from("direct_messages")
        .insert({
          sender_uid: senderId,
          receiver_uid: receiverId,
          content,
          is_read: false,
        })
        .select()
        .single();

      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
      return NextResponse.json({ success: true, data: dm });
    }

    return NextResponse.json({ error: "Action non valide" }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
