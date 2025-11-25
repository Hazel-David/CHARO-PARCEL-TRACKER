# Admin Panel Implementation Plan

## 🎯 Overview

We'll create an **Admin Panel** within the app that allows authorized admins to:
- View all parcels (from all users)
- Search and filter parcels
- Update parcel status (Pending → In Transit → Out for Delivery → Delivered)
- Update current location (county)
- View parcel details and history

---

## 📋 Implementation Outline

### **Phase 1: Database Setup & Admin Authentication**

#### 1.1 Add Admin Role to Users Table
**What we need:**
- Add `role` column to `users` table (default: 'user', can be 'admin')
- Or add `is_admin` boolean field (simpler)

**SQL:**
```sql
-- Option 1: Role-based (more flexible for future)
ALTER TABLE users 
ADD COLUMN role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin'));

-- Option 2: Boolean flag (simpler)
ALTER TABLE users 
ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;

-- Make your account admin (replace with your email)
UPDATE users 
SET is_admin = TRUE 
WHERE email = 'your-admin-email@example.com';
```

**Decision needed:** Role-based or boolean flag?

---

#### 1.2 Check Admin Status on Login
**Location:** `lib/main.dart` - `_handleSignIn()`

**What to do:**
- After successful login, check if user has admin role
- Store admin status in user object passed to Dashboard
- Dashboard will show/hide admin features based on this

**Code change:**
```dart
// After successful login
final isAdmin = user['is_admin'] == true || user['role'] == 'admin';

// Pass to Dashboard
DashboardScreen(
  user: user,
  isAdmin: isAdmin, // New parameter
)
```

---

### **Phase 2: UI Structure**

#### 2.1 Admin Tab in Dashboard
**Location:** `lib/dashboard.dart`

**Approach:** Add a 4th tab (Admin) that only appears for admin users

**Current tabs:** Home, Profile, Settings (3 tabs)
**New tabs:** Home, Profile, Settings, Admin (4 tabs for admins only)

**Implementation:**
- Modify `TabController` to have 4 tabs if user is admin, 3 if not
- Add conditional tab in `TabBar` and `TabBarView`
- Style admin tab differently (maybe with badge/icon)

---

#### 2.2 Admin Panel Layout
**Location:** `lib/dashboard.dart` - New `_AdminTab` widget

**Components:**
```
┌─────────────────────────────────────┐
│  Admin Panel Header                 │
│  [Search Bar] [Filter Button]       │
├─────────────────────────────────────┤
│  Statistics Cards                   │
│  [Total Parcels] [In Transit]      │
│  [Pending] [Delivered]              │
├─────────────────────────────────────┤
│  Parcels List                       │
│  ┌───────────────────────────────┐ │
│  │ PARC-0001-2025                │ │
│  │ From: Nairobi → To: Mombasa   │ │
│  │ Status: In Transit            │ │
│  │ [View Details] [Update]        │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ PARC-0002-2025                │ │
│  │ ...                           │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

### **Phase 3: Core Functionality**

#### 3.1 View All Parcels
**What it does:**
- Fetches all parcels from database (not just current user's)
- Displays in scrollable list
- Shows key info: parcel_id, route, status, owner

**Database query:**
```dart
final parcels = await _supabase
  .from('parcels')
  .select('*, users(full_name, email)') // Join with users table
  .order('created_at', ascending: false);
```

---

#### 3.2 Search & Filter
**Search by:**
- Parcel ID
- User name/email
- From/To county
- Status

**Filter by:**
- Status (Pending, In Transit, Delivered)
- Courier service
- Date range

**UI:**
- Search bar at top
- Filter chips/buttons
- Real-time filtering as user types

---

#### 3.3 Update Parcel Dialog
**Location:** `lib/dashboard.dart` - `_UpdateParcelDialog` widget

**What it shows:**
- Parcel details (read-only)
- Status dropdown (Pending, In Transit, Out for Delivery, Delivered)
- Current Location dropdown (47 Kenyan counties)
- Notes field (optional)
- Update button

**UI Layout:**
```
┌─────────────────────────────────────┐
│  Update Parcel                      │
│  ─────────────────────────────────  │
│  Parcel ID: PARC-0001-2025          │
│  Owner: John Doe                    │
│  Route: Nairobi → Mombasa           │
│                                     │
│  Status: [Dropdown ▼]              │
│  ┌───────────────────────────────┐ │
│  │ Pending                       │ │
│  │ In Transit                    │ │
│  │ Out for Delivery              │ │
│  │ Delivered                     │ │
│  └───────────────────────────────┘ │
│                                     │
│  Current Location: [Dropdown ▼]    │
│  ┌───────────────────────────────┐ │
│  │ Nairobi                       │ │
│  │ Mombasa                       │ │
│  │ ... (47 counties)            │ │
│  └───────────────────────────────┘ │
│                                     │
│  Notes (optional):                  │
│  [Text field]                       │
│                                     │
│  [Cancel]  [Update Parcel]          │
└─────────────────────────────────────┘
```

---

#### 3.4 Update Database
**Location:** `lib/dashboard.dart` - `_updateParcel()` method

**What it does:**
- Updates `status` field
- Updates `current_location` field (if we add it)
- Updates `updated_at` timestamp
- Optionally logs to `tracking_history` table

**Database update:**
```dart
await _supabase
  .from('parcels')
  .update({
    'status': newStatus,
    'current_location': newLocation,
    'updated_at': DateTime.now().toIso8601String(),
  })
  .eq('parcel_id', parcelId);
```

---

### **Phase 4: Enhanced Features (Optional)**

#### 4.1 Tracking History
**What it does:**
- Log every status/location change
- Show timeline of changes
- Track who made the change (admin user)

**New table:**
```sql
CREATE TABLE tracking_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parcel_id TEXT NOT NULL,
  status TEXT,
  location TEXT,
  updated_by TEXT, -- Admin user ID
  updated_at TIMESTAMP DEFAULT NOW(),
  notes TEXT
);
```

---

#### 4.2 Statistics Dashboard
**What it shows:**
- Total parcels
- Parcels by status (pie chart or cards)
- Parcels by courier service
- Recent updates

---

#### 4.3 Bulk Operations
**What it does:**
- Select multiple parcels
- Bulk update status
- Export to CSV

---

## 📁 Files to Create/Modify

### **Files to Modify:**

1. **`lib/main.dart`**
   - Add admin check in `_handleSignIn()`
   - Pass `isAdmin` to `DashboardScreen`

2. **`lib/dashboard.dart`**
   - Add `isAdmin` parameter to `DashboardScreen`
   - Modify `TabController` to support 4 tabs for admins
   - Add `_AdminTab` widget
   - Add `_UpdateParcelDialog` widget
   - Add `_updateParcel()` method
   - Add `_loadAllParcels()` method

### **Files to Create (Optional):**

3. **`lib/widgets/admin_parcel_card.dart`**
   - Reusable card widget for parcel list in admin panel

4. **`lib/widgets/parcel_update_dialog.dart`**
   - Separate file for update dialog (if it gets too large)

---

## 🔐 Security Considerations

### **1. Admin Access Control**
- Only show admin tab if `isAdmin == true`
- Check admin status before allowing updates
- Add RLS policy to allow admins to read all parcels

### **2. Database Security**
**RLS Policy for Admin:**
```sql
-- Allow admins to read all parcels
CREATE POLICY "Admins can view all parcels"
ON parcels FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.is_admin = TRUE
  )
);

-- Allow admins to update parcels
CREATE POLICY "Admins can update parcels"
ON parcels FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.is_admin = TRUE
  )
);
```

**Note:** Since you're using password hashing (not Supabase Auth), you'll need to adjust RLS or use service role key for admin operations.

---

## 🎨 UI/UX Design

### **Color Scheme:**
- Admin tab: Different color (maybe orange/red) to distinguish
- Update buttons: Prominent, maybe with icons
- Status badges: Color-coded (green=delivered, orange=in transit, etc.)

### **Animations:**
- Smooth transitions when opening update dialog
- Loading indicators during updates
- Success/error toasts after updates

### **Responsive:**
- Works on phones and tablets
- Search bar adapts to screen size
- List items scroll smoothly

---

## 📝 Step-by-Step Implementation Order

### **Step 1: Database Setup** ⏱️ 5 min
1. Add `is_admin` column to `users` table
2. Set your account as admin
3. Test query to verify

### **Step 2: Admin Detection** ⏱️ 10 min
1. Modify `_handleSignIn()` to check admin status
2. Pass `isAdmin` to `DashboardScreen`
3. Test with admin and non-admin accounts

### **Step 3: Admin Tab UI** ⏱️ 30 min
1. Modify `TabController` to support 4 tabs
2. Add conditional Admin tab
3. Create basic `_AdminTab` widget
4. Test tab switching

### **Step 4: Parcels List** ⏱️ 30 min
1. Create `_loadAllParcels()` method
2. Display parcels in list
3. Add search functionality
4. Test with real data

### **Step 5: Update Dialog** ⏱️ 45 min
1. Create `_UpdateParcelDialog` widget
2. Add status dropdown
3. Add location dropdown
4. Add form validation
5. Test dialog opening/closing

### **Step 6: Update Functionality** ⏱️ 30 min
1. Create `_updateParcel()` method
2. Connect to database
3. Add success/error handling
4. Refresh list after update
5. Test complete flow

### **Step 7: Polish & Testing** ⏱️ 30 min
1. Add loading states
2. Add animations
3. Add error messages
4. Test edge cases
5. Fix any bugs

**Total Estimated Time:** ~3 hours

---

## 🧪 Testing Checklist

- [ ] Admin can see Admin tab
- [ ] Non-admin cannot see Admin tab
- [ ] Admin can view all parcels
- [ ] Search works correctly
- [ ] Filter works correctly
- [ ] Update dialog opens with correct data
- [ ] Status update saves to database
- [ ] Location update saves to database
- [ ] List refreshes after update
- [ ] Error handling works
- [ ] Loading states show correctly

---

## ❓ Questions to Answer Before Implementation

1. **Admin Identification:**
   - Use `is_admin` boolean or `role` text field?
   - How will you initially set yourself as admin?

2. **Current Location Field:**
   - Add `current_location` column to `parcels` table?
   - Or use existing `from_county`/`to_county`?

3. **Status Options:**
   - Exact statuses: "Pending", "In Transit", "Out for Delivery", "Delivered"?
   - Any others?

4. **Tracking History:**
   - Implement now or later?
   - Track who made changes?

5. **Access Method:**
   - Admin tab visible to all admins?
   - Or hidden access (e.g., long-press Settings)?

---

## 🚀 Ready to Start?

Once you answer the questions above, I can begin implementation. The plan is flexible and can be adjusted as we go.

**Recommended starting point:**
1. Add `is_admin` column
2. Set your account as admin
3. Add admin tab to dashboard
4. Build basic parcels list
5. Add update functionality

Let me know if you want to proceed or have any questions about the plan!

