# Admin Dashboard Deployment Guide

## Overview

This document provides step-by-step instructions for deploying your e-commerce application with the admin dashboard functionality to production environments.

## Prerequisites

1. Firebase project set up (Firestore, Authentication, Storage)
2. Flutter development environment configured
3. Access to the application source code

## Deployment Steps

### 1. Firebase Configuration

#### Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

This will deploy the security rules that protect your admin functionality.

#### Deploy Storage Security Rules

```bash
firebase deploy --only storage:rules
```

### 2. Admin User Creation

Before deploying to production:

1. Create at least one admin user using the AdminSetupTool
2. Save the admin credentials in a secure location
3. Test admin login and functionality

### 3. Environment Configuration

Create or update `.env` files for different environments:

- `.env.dev` - Development environment
- `.env.prod` - Production environment

Include the following environment-specific configurations:
```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_REGION=your-region
ENABLE_ANALYTICS=true/false
```

### 4. Build & Deploy Web Version

```bash
# Build for web
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### 5. Build & Deploy Mobile Versions

#### Android

```bash
# Build Android APK
flutter build apk --release

# Build Android App Bundle for Play Store
flutter build appbundle --release
```

#### iOS

```bash
# Build iOS
flutter build ios --release

# Archive and upload using Xcode
open ios/Runner.xcworkspace
```

Then use Xcode to archive and submit to the App Store.

### 6. Post-Deployment Steps

#### Verify Admin Access

1. Access the deployed application
2. Login with admin credentials
3. Verify all admin dashboard sections are working

#### Security Review

1. Verify Firestore security rules are enforced
2. Check that only admin users can access admin features
3. Confirm authentication is working correctly

#### Generate Initial Data

If deploying to a new environment:

1. Access the admin dashboard
2. Use the Sample Data Generator if needed for initial setup
3. Create real announcements, categories, etc.

## Monitoring & Maintenance

### Firebase Console

Regularly check:
- Authentication users
- Firestore data integrity
- Storage usage
- Crash reports

### Analytics & Performance

Monitor:
- User engagement with the admin dashboard
- Performance metrics
- Error rates

### Backup Strategy

1. Set up regular Firestore exports
2. Document recovery procedures
3. Test restoration process periodically

## Troubleshooting

### Common Issues

#### Admin Access Issues

**Problem**: Unable to access admin dashboard after deployment
**Solution**: 
- Verify admin role is correctly set in Firestore
- Check security rules deployment
- Confirm Firebase services are properly initialized

#### Data Loading Issues

**Problem**: Dashboard shows empty data
**Solution**:
- Check network connectivity
- Verify Firestore paths match application code
- Confirm security rules allow admin read access

#### Authentication Issues

**Problem**: Unable to log in with admin credentials
**Solution**:
- Reset admin password
- Verify Firebase Authentication service is active
- Check for proper initialization in the app

## Support

For issues with the admin dashboard, contact:
- Technical support: support@example.com
- Project developer documentation: `/docs/admin_architecture.md`

## Future Updates

To deploy updates to the admin dashboard:

1. Develop and test changes in development environment
2. Update version numbers in pubspec.yaml
3. Follow the build and deployment steps above
4. Document changes in the release notes
