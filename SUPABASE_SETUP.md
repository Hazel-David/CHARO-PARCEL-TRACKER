# Supabase Edge Function Setup Guide

This guide will help you set up the Gemini AI chatbot Edge Function in your Supabase project.

## Prerequisites

- Supabase project (already set up)
- Google Gemini API key (you already have this)

## Step 1: Install Supabase CLI

1. Install Supabase CLI if you haven't already:
   - **Windows**: Download from https://github.com/supabase/cli/releases
   - Or use: `scoop install supabase`
   - Or use: `choco install supabase`

2. Verify installation:
   ```bash
   supabase --version
   ```

## Step 2: Login to Supabase

```bash
supabase login
```

This will open your browser to authenticate.

## Step 3: Link Your Project

```bash
supabase link --project-ref tdxmhtxlhekauustcwku
```

Replace `tdxmhtxlhekauustcwku` with your actual project reference if different.

## Step 4: Set Up Edge Function

1. The Edge Function file is already created at:
   ```
   supabase/functions/gemini-chat/index.ts
   ```

2. Deploy the function:
   ```bash
   supabase functions deploy gemini-chat
   ```

## Step 5: Set Environment Variables (API Key)

You need to set your Gemini API key as a secret in Supabase:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_api_key_here
```

**Important**: Replace `your_gemini_api_key_here` with your actual Gemini API key.

## Step 6: Verify the Function

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Navigate to: **Edge Functions** → **gemini-chat**
3. You should see the function listed

## Alternative: Manual Setup via Supabase Dashboard

If you prefer using the web interface:

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to **Edge Functions** in the sidebar
4. Click **Create a new function**
5. Name it: `gemini-chat`
6. Copy the contents from `supabase/functions/gemini-chat/index.ts`
7. Paste into the function editor
8. Click **Deploy**

### Set Secret via Dashboard:

1. Go to **Project Settings** → **Edge Functions** → **Secrets**
2. Add a new secret:
   - **Name**: `GEMINI_API_KEY`
   - **Value**: Your Gemini API key
3. Click **Save**

## Testing the Function

You can test the function using curl or Postman:

```bash
curl -X POST \
  'https://tdxmhtxlhekauustcwku.supabase.co/functions/v1/gemini-chat' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Where is my parcel?",
    "userId": "your_user_id_here"
  }'
```

## Troubleshooting

### Function not found (404)
- Make sure the function is deployed
- Check the function name matches exactly: `gemini-chat`
- Verify the URL path: `/functions/v1/gemini-chat`

### API Key error
- Verify the secret is set: `supabase secrets list`
- Make sure the secret name is exactly: `GEMINI_API_KEY`
- Redeploy the function after setting the secret

### CORS errors
- The function already includes CORS headers
- If issues persist, check Supabase project CORS settings

### Rate limiting
- Gemini free tier: 60 requests/minute
- Consider implementing caching for common queries

## Next Steps

Once the Edge Function is deployed and the API key is set:
1. Run your Flutter app
2. Click the chat button (FloatingActionButton with chat icon)
3. Start chatting with the AI assistant!

## Security Notes

- ✅ API key is stored securely in Supabase secrets
- ✅ Function validates user authentication
- ✅ Only user's own parcels are accessible
- ✅ CORS is properly configured

