// Supabase Edge Function for Gemini AI Chat
// This function securely calls Google Gemini API with user's parcel data

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Using v1 API with gemini-1.5-flash (v1beta doesn't support newer models)
// Alternative: Use gemini-pro with v1beta if this doesn't work
//const GEMINI_API_URL =
  //"https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent";
// pick a model you actually have access to, e.g. gemini-1.5-flash
const GEMINI_MODEL = "gemini-2.5-flash";

const GEMINI_API_URL =
  `https://generativelanguage.googleapis.com/v1/models/${GEMINI_MODEL}:generateContent`;

interface RequestBody {
  message: string;
  userId: string;
}

serve(async (req: Request): Promise<Response> => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    // Get Gemini API key from Supabase secrets
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY not found in environment variables");
    }

    // Get Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Parse request body
    const { message, userId } = (await req.json()) as RequestBody;

    if (!message || !userId) {
      return new Response(
        JSON.stringify({ error: "Message and userId are required" }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    // Fetch user's parcels from database
    const { data: parcels, error: parcelsError } = await supabase
      .from("parcels")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (parcelsError) {
      console.error("Error fetching parcels:", parcelsError);
    }

    // Format parcels data for AI context
    const parcelsContext =
      parcels && parcels.length > 0
        ? parcels.map((p: any) => ({
            parcel_id: p.parcel_id || "N/A",
            from_county: p.from_county || "Unknown",
            to_county: p.to_county || "Unknown",
            status: p.status || "Unknown",
            courier_service: p.courier_service || "Unknown",
            created_at: p.created_at || "Unknown",
            description: p.description || "No description",
            recipient_name: p.recipient_name || "Unknown",
          }))
        : [];

    // Create system prompt
    const systemPrompt = `You are a helpful and friendly parcel tracking assistant for ChaRo Parcel Tracker, a parcel tracking service in Kenya.

User's current parcels:
${JSON.stringify(parcelsContext, null, 2)}

Current user question: ${message}

Provide a helpful response:`;

    // Call Gemini API - try v1 first, fallback to v1beta with gemini-pro
    let geminiResponse = await fetch(
      `${GEMINI_API_URL}?key=${geminiApiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: systemPrompt,
                },
              ],
            },
          ],
        }),
      },
    );

    // If v1 fails with 404, try v1beta with gemini-pro
    

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini API error:", errorText);
      console.error("API URL used:", GEMINI_API_URL);
      throw new Error(`Gemini API error: ${geminiResponse.status} - ${errorText}`);
    }

    const geminiData = await geminiResponse.json();

    // Extract response text
    const responseText =
      geminiData.candidates?.[0]?.content?.parts?.[0]?.text ||
      "I apologize, but I could not generate a response. Please try again.";

    return new Response(
      JSON.stringify({
        response: responseText,
        success: true,
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  } catch (error) {
    console.error("Error in gemini-chat function:", error);

    const message =
      error instanceof Error ? error.message : "An error occurred";

    return new Response(
      JSON.stringify({
        error: message,
        success: false,
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  }
});
