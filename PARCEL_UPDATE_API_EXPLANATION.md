# Option 3: Supabase Edge Function API - Detailed Explanation

## 📚 What is a Supabase Edge Function?

A **Supabase Edge Function** is a serverless function that runs on Deno (a JavaScript/TypeScript runtime). Think of it as a **secure middleman** between your Flutter app and your database.

### Why Use Edge Functions Instead of Direct Database Access?

1. **Security**: Your app never directly touches the database with admin privileges
2. **Validation**: Server-side validation ensures data integrity
3. **Flexibility**: Can add complex logic, logging, notifications, etc.
4. **Scalability**: Handles multiple requests efficiently

---

## 🔄 How It Works (Using Your Gemini Chat as Example)

### Current Flow (Gemini Chat):
```
Flutter App → Edge Function → Gemini API → Edge Function → Flutter App
                ↓
           Supabase Database (reads parcels)
```

### Proposed Flow (Parcel Update):
```
Flutter App → Edge Function → Supabase Database (updates parcel)
                ↓
           Validation & Security Checks
```

---

## 🏗️ Architecture Breakdown

### 1. **Edge Function** (`supabase/functions/update-parcel/index.ts`)

**Location**: `supabase/functions/update-parcel/index.ts`

**What it does**:
- Receives HTTP POST request from Flutter app
- Validates admin credentials (API key or user role)
- Validates the update data (parcel_id, status, location, etc.)
- Updates the database securely
- Returns success/error response

**Key Components**:
```typescript
// 1. Handle CORS (for web compatibility)
if (req.method === "OPTIONS") {
  return new Response("ok", { headers: {...} });
}

// 2. Get admin credentials from request
const adminKey = req.headers.get("x-admin-key");

// 3. Validate admin (check against stored admin key or user role)
if (!isValidAdmin(adminKey)) {
  return error("Unauthorized");
}

// 4. Parse request body
const { parcelId, status, currentLocation } = await req.json();

// 5. Validate data
if (!parcelId || !status) {
  return error("Missing required fields");
}

// 6. Update database
const { data, error } = await supabase
  .from("parcels")
  .update({ 
    status: status,
    current_location: currentLocation,
    updated_at: new Date().toISOString()
  })
  .eq("parcel_id", parcelId);

// 7. Return response
return success("Parcel updated successfully");
```

---

### 2. **Flutter Service** (`lib/services/parcel_update_service.dart`)

**Location**: `lib/services/parcel_update_service.dart`

**What it does**:
- Makes HTTP POST request to Edge Function
- Sends admin credentials
- Sends parcel update data
- Handles response/errors

**Example Code Structure**:
```dart
class ParcelUpdateService {
  // Supabase URL and keys
  static const String _supabaseUrl = 'https://tdxmhtxlhekauustcwku.supabase.co';
  static const String _supabaseAnonKey = '...';
  
  // Admin API key (stored securely)
  static const String _adminKey = 'your-secret-admin-key';
  
  /// Update parcel status and location
  Future<bool> updateParcel({
    required String parcelId,
    required String status,
    String? currentLocation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/update-parcel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_supabaseAnonKey',
          'apikey': _supabaseAnonKey,
          'x-admin-key': _adminKey, // Admin authentication
        },
        body: jsonEncode({
          'parcelId': parcelId,
          'status': status,
          'currentLocation': currentLocation,
        }),
      );
      
      if (response.statusCode == 200) {
        return true; // Success
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
```

---

### 3. **UI Component** (Admin Panel in Dashboard)

**Location**: `lib/dashboard.dart` (new admin tab or dialog)

**What it does**:
- Shows list of all parcels
- Allows admin to select a parcel
- Shows form to update status/location
- Calls `ParcelUpdateService` to update
- Shows success/error messages

---

## 🔐 Security Implementation

### Option A: API Key Authentication (Simple)
```typescript
// In Edge Function
const ADMIN_API_KEY = Deno.env.get("ADMIN_API_KEY"); // Stored in Supabase secrets
const providedKey = req.headers.get("x-admin-key");

if (providedKey !== ADMIN_API_KEY) {
  return new Response(JSON.stringify({ error: "Unauthorized" }), {
    status: 401,
  });
}
```

**Pros**: Simple, works immediately  
**Cons**: Single key for all admins, harder to track who made changes

---

### Option B: User Role-Based (More Secure)
```typescript
// In Edge Function
const authHeader = req.headers.get("Authorization");
const token = authHeader?.replace("Bearer ", "");

// Verify JWT token
const { data: { user }, error } = await supabase.auth.getUser(token);

if (error || !user) {
  return error("Unauthorized");
}

// Check if user has admin role
const { data: userData } = await supabase
  .from("users")
  .select("role")
  .eq("id", user.id)
  .single();

if (userData?.role !== "admin") {
  return error("Admin access required");
}
```

**Pros**: Per-user authentication, audit trail, more secure  
**Cons**: Requires user role system in database

---

## 📊 Database Schema Updates Needed

### Current `parcels` table fields:
- `parcel_id`
- `user_id`
- `from_county`
- `to_county`
- `status` (Pending, In Transit, Delivered)
- `created_at`
- `updated_at`

### Recommended additions:
```sql
-- Add current_location field
ALTER TABLE parcels 
ADD COLUMN current_location TEXT;

-- Add tracking_history table (optional, for audit trail)
CREATE TABLE tracking_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parcel_id TEXT NOT NULL,
  status TEXT NOT NULL,
  location TEXT,
  updated_by TEXT, -- Admin user ID
  updated_at TIMESTAMP DEFAULT NOW(),
  notes TEXT
);
```

---

## 🔄 Complete Update Flow

### Step-by-Step:

1. **Admin opens update dialog** in Flutter app
2. **Selects parcel** from list
3. **Chooses new status** (e.g., "In Transit")
4. **Enters current location** (e.g., "Nairobi")
5. **Clicks "Update"**
6. **Flutter app calls** `ParcelUpdateService.updateParcel()`
7. **Service sends HTTP POST** to Edge Function with:
   - Admin credentials
   - Parcel ID
   - New status
   - New location
8. **Edge Function validates**:
   - Admin is authorized
   - Parcel exists
   - Data is valid
9. **Edge Function updates** database:
   - Updates `parcels` table
   - Optionally logs to `tracking_history`
10. **Edge Function returns** success/error
11. **Flutter app shows** success message
12. **Dashboard refreshes** to show updated parcel

---

## 🎯 Advantages of This Approach

### ✅ Security
- Admin credentials never stored in app code
- Server-side validation prevents bad data
- Can add rate limiting, IP whitelisting, etc.

### ✅ Scalability
- Can handle many updates per second
- Works from any device (mobile, web, desktop)
- Can add webhooks/notifications later

### ✅ Maintainability
- All update logic in one place (Edge Function)
- Easy to add features (email notifications, SMS alerts, etc.)
- Can version control the function

### ✅ Flexibility
- Can add complex business rules
- Can integrate with external APIs (SMS, email)
- Can generate reports, analytics

---

## 🚀 Implementation Steps

1. **Create Edge Function** (`supabase/functions/update-parcel/index.ts`)
2. **Add admin authentication** (API key or role-based)
3. **Deploy function** to Supabase
4. **Create Flutter service** (`lib/services/parcel_update_service.dart`)
5. **Add admin UI** in dashboard (dialog or new tab)
6. **Test** with sample parcel updates
7. **Add database fields** if needed (`current_location`, etc.)

---

## 📝 Example Request/Response

### Request (from Flutter):
```json
POST https://tdxmhtxlhekauustcwku.supabase.co/functions/v1/update-parcel
Headers:
  Authorization: Bearer <anon-key>
  apikey: <anon-key>
  x-admin-key: <secret-admin-key>
  Content-Type: application/json

Body:
{
  "parcelId": "PARC-0001-2025",
  "status": "In Transit",
  "currentLocation": "Nairobi"
}
```

### Response (from Edge Function):
```json
{
  "success": true,
  "message": "Parcel updated successfully",
  "parcel": {
    "parcel_id": "PARC-0001-2025",
    "status": "In Transit",
    "current_location": "Nairobi",
    "updated_at": "2025-01-15T10:30:00Z"
  }
}
```

---

## ❓ Questions to Consider

1. **Who are the admins?**
   - Single admin? → Use API key
   - Multiple admins? → Use role-based auth

2. **What can be updated?**
   - Status only?
   - Location only?
   - Both?
   - Other fields (courier, recipient, etc.)?

3. **Do you need history?**
   - Track who changed what?
   - Timeline of all changes?

4. **Notifications?**
   - Email user when status changes?
   - SMS alerts?

---

## 🎬 Next Steps

Once you understand this approach, I can:
1. Create the Edge Function code
2. Set up the Flutter service
3. Build the admin UI
4. Add security/authentication
5. Test the complete flow

Would you like me to proceed with implementation, or do you have questions about any part?

