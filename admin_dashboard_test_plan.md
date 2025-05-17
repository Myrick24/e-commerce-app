# Admin Dashboard Test Plan

## Overview

This document outlines a comprehensive testing plan for the admin dashboard of the e-commerce Flutter application. It covers all key functionality and provides step-by-step test cases to ensure everything works as expected.

## Prerequisites

1. Firebase project with Firestore, Authentication, and Storage enabled
2. Admin user created in the system
3. Sample data generated for testing

## Test Areas

### 1. Authentication & Access Control

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Admin Login | 1. Navigate to login screen<br>2. Enter admin credentials<br>3. Click login | Successfully redirected to admin dashboard |
| Regular User Access | 1. Login with non-admin account<br>2. Try to access admin routes | Access denied message shown |
| Admin Validation | 1. Login as admin<br>2. Navigate to admin dashboard | Admin role verified and dashboard loads |

### 2. Dashboard Home

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Stats Display | 1. Login as admin<br>2. Navigate to dashboard home | All metrics (users, sellers, products, transactions) displayed correctly |
| Recent Activity | 1. View dashboard home | Recent user registrations, product listings, and transactions displayed in chronological order |
| Charts & Graphs | 1. View dashboard home | Sales/user analytics charts render correctly with accurate data |

### 3. User Management

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| View Users | 1. Navigate to User Management | List of all users displayed with roles and status |
| Filter Users | 1. Navigate to User Management<br>2. Use filter dropdown | Users filtered correctly by role (customer/seller/admin) |
| Approve Seller | 1. Navigate to User Management<br>2. Find pending seller<br>3. Click approve button | Seller status changes to "approved" |
| Reject Seller | 1. Navigate to User Management<br>2. Find pending seller<br>3. Click reject button | Seller status changes to "rejected" |
| View Seller Details | 1. Navigate to User Management<br>2. Click on seller name | Detailed seller information displayed |

### 4. Product Listings

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| View Products | 1. Navigate to Products | All product listings displayed with status |
| Filter Products | 1. Navigate to Products<br>2. Use category filter | Products filtered correctly by category |
| Approve Product | 1. Navigate to Products<br>2. Find pending product<br>3. Click approve button | Product status changes to "approved" |
| Reject Product | 1. Navigate to Products<br>2. Find pending product<br>3. Click reject button | Product status changes to "rejected" |
| View Product Details | 1. Navigate to Products<br>2. Click on product | Detailed product information displayed |

### 5. Transaction Monitoring

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| View Transactions | 1. Navigate to Transactions | All transactions displayed with status |
| Filter Transactions | 1. Navigate to Transactions<br>2. Use status filter | Transactions filtered correctly by status |
| Transaction Details | 1. Navigate to Transactions<br>2. Click on transaction | Detailed transaction information displayed |
| Update Transaction | 1. Navigate to Transactions<br>2. Click on transaction<br>3. Change status<br>4. Save | Transaction status updated successfully |

### 6. Announcements

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| View Announcements | 1. Navigate to Announcements | All announcements displayed |
| Create Announcement | 1. Navigate to Announcements<br>2. Click "New Announcement"<br>3. Fill form<br>4. Submit | Announcement created and displayed in list |
| Edit Announcement | 1. Navigate to Announcements<br>2. Click on announcement<br>3. Edit fields<br>4. Save | Announcement updated successfully |
| Delete Announcement | 1. Navigate to Announcements<br>2. Click delete button on announcement | Announcement removed from list |

### 7. Admin Settings

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| View Profile | 1. Navigate to Settings | Admin profile information displayed |
| Update Profile | 1. Navigate to Settings<br>2. Edit profile information<br>3. Save | Profile updated successfully |
| Change Password | 1. Navigate to Settings<br>2. Click "Change Password"<br>3. Enter old and new passwords<br>4. Submit | Password changed successfully |

### 8. Data Generation Tools

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Generate Sample Data | 1. Access Sample Data Tool<br>2. Set password for test users<br>3. Click generate | Sample users, products, transactions, and announcements created |
| Verify Sample Data | 1. Generate sample data<br>2. Navigate through dashboard sections | Sample data visible in all relevant sections |

### 9. Security Testing

| Test Case | Steps | Expected Result |
|-----------|-------|-----------------|
| Firestore Rules | 1. Login as regular user<br>2. Attempt to access admin collections via direct API calls | Access denied by security rules |
| Role-Based Access | 1. Modify user document to add admin role<br>2. Try to access admin features | Proper validation prevents unauthorized access |

## Reporting Issues

When identifying issues during testing, document the following:

1. Test case being executed
2. Steps to reproduce the issue
3. Expected vs. actual behavior
4. Screenshots or logs showing the issue
5. Environment details (device, OS, app version)

## Test Execution Checklist

- [ ] All authentication tests passed
- [ ] Dashboard home functionality verified
- [ ] User management features working
- [ ] Product listing management verified
- [ ] Transaction monitoring operational
- [ ] Announcements functionality working
- [ ] Admin settings functions properly
- [ ] Sample data generation tested
- [ ] Security testing completed

## Completion Criteria

The admin dashboard testing is considered complete when:
1. All test cases have been executed
2. All critical and high-priority bugs have been fixed
3. Performance is acceptable on both mobile and web platforms
4. Security validation has confirmed proper access controls
