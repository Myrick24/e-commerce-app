# Admin Dashboard Guide

## Overview
This guide explains how to set up and use the admin dashboard for your e-commerce Flutter application.

## Setup Instructions

### 1. Create Admin User
1. Run your application
2. Navigate to `/admin-setup` by typing the following URL:
   - For web: `http://localhost:XXXX/#/admin-setup` (replace XXXX with your port)
   - For mobile emulator: add '/admin-setup' to your route in `main.dart`

3. Fill in the admin details:
   - Name (e.g., "Admin User")
   - Email (must be a valid format)
   - Password (should be strong)
   
4. Click "Create Admin User"
   - Save the User UID shown in the success message (for reference)

### 2. Login as Admin
1. Navigate to the login screen
2. Enter the admin credentials you just created
3. The system will automatically detect the admin role and direct you to the admin dashboard

## Using the Admin Dashboard

### Dashboard Home
- View key statistics: total users, approved sellers, active listings, completed transactions
- Monitor recent activity: user registrations, product listings, transactions
- View sales analytics with charts

### User Management
- View all users in the system
- Filter/search users by role (customer, seller, admin)
- Approve or reject seller requests
- Edit user roles and permissions
- View seller details and documents

### Product Listings
- View all product listings
- Approve or reject new product listings
- Edit product details or remove listings
- Filter products by category, status, or seller

### Transaction Monitoring
- Track all transactions in the system
- View transaction details including buyer, seller, products, and amounts
- Filter transactions by status (pending, completed, cancelled)
- Resolve transaction disputes

### Announcements
- Create system-wide announcements for all users
- Send targeted notifications to specific user groups
- Manage customer support requests

### Admin Settings
- Update admin profile information
- Manage app settings and configurations
- Configure notification preferences

## Security Rules

Firestore security rules are in place to ensure:
- Only admins can access admin-specific collections and documents
- Regular users cannot modify admin data or settings
- Data integrity is maintained across all operations

## Next Steps

1. **Complete Security Implementation**
   - Deploy Firestore rules (`firebase deploy --only firestore:rules`)
   - Test rule effectiveness with different user roles

2. **Generate Sample Data**
   - Access the Sample Data Generator from the admin dashboard drawer menu
   - Navigate to `/sample-data` directly in your browser
   - Generate test users, products, transactions, and announcements with a single click

3. **Testing All Features**
   - Verify admin permissions and access controls
   - Test approval/rejection workflows
   - Confirm notification delivery

4. **Implement Advanced Reporting**
   - Set up scheduled reports
   - Create exportable data functions

For technical support, refer to the Firebase documentation at https://firebase.google.com/docs
