# LMS API Mapping Sheet

## Base URL
`http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/`

---

## Authentication APIs

### Sign In Screen

| Field | Value |
|-------|-------|
| **Screen Name** | Sign in Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/login/{phoneNumber}` |
| **Method** | POST |
| **Endpoint** | `/login` |

**Request JSON:**
```json
{
  "phoneNumber": "Number(10)",
  "passcode": "string"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "token": "string",
    "refreshToken": "string",
    "expiresIn": 86400,
    "phone_number": "string"
  }
}
```

**Remarks:** Authentication endpoint for user login with phone number and passcode.

---

## Dashboard APIs

### Dashboard Data

| Field | Value |
|-------|-------|
| **Screen Name** | Dashboard |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/data/{phoneNumber}` |
| **Method** | GET |
| **Endpoint** | `/data/{phoneNumber}` |

**Request JSON:**
```json
{
  "token": "string",
  "refreshToken": "string",
  "phoneNumber": "number(10)"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "emp_pk": 106,
    "card_no": "10000106.1.2",
    "emp_no": "F-84",
    "emp_name": "FURQAN HASAN",
    "date_of_join": "2019-11-21T19:00:00Z",
    "nic_no": "42201-1129652-9",
    "designation": "DY. GENERAL MANAGER",
    "department": "IT",
    "compcnm": "KARACHI",
    "brnchnm": "Head Office",
    "hod": 3008228498,
    "hod_nm": "ALTAF HUSSAIN"
  }
}
```

**Remarks:** Fetches employee dashboard data including personal info, department, and HOD details.

---

## Attendance APIs

### Mark Biometric Attendance

| Field | Value |
|-------|-------|
| **Screen Name** | Biometric Attendance Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/biometric` |
| **Method** | POST |
| **Endpoint** | `/attendance/biometric` |

**Request JSON:**
```json
{
  "employee_id": "string",
  "attendance_type": "check_in | check_out",
  "biometric_type": "fingerprint | face",
  "location": {
    "latitude": "number (decimal)",
    "longitude": "number (decimal)",
    "accuracy": "number (meters)",
    "timestamp": "ISO8601 datetime string",
    "address": "string (optional)",
    "street_address": "string (optional)",
    "locality": "string (city/town)",
    "sub_locality": "string (neighborhood)",
    "postal_code": "string (optional)",
    "country": "string",
    "nearest_landmark": "string (nearby notable place)",
    "famous_place": "string (well-known location nearby)",
    "distance_to_landmark": "number (meters)",
    "formatted_address": "string (full human-readable address)"
  },
  "timestamp": "ISO8601 datetime string",
  "device_id": "string (optional)",
  "device_model": "string (optional)",
  "app_version": "string (optional)"
}
```

**Response JSON (Success):**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": "Attendance marked successfully"
  },
  "body": {
    "attendance_id": "ATT-1702056789123",
    "marked_at": "2024-12-08T09:30:00Z",
    "location_verified": true,
    "biometric_verified": true
  }
}
```

**Response JSON (Error):**
```json
{
  "header": {
    "code": 400,
    "status": "error",
    "message": "Biometric verification failed",
    "error_code": "BIO_VERIFY_FAILED"
  },
  "body": null
}
```

**Remarks:** 
- Marks attendance using biometric (fingerprint or face) authentication
- Sends complete location data including coordinates, address, and nearest landmarks
- Location data is used for geofence verification and audit trail
- Device info helps in identifying the source device for security purposes

---

### Get Attendance Report

| Field | Value |
|-------|-------|
| **Screen Name** | Attendance History Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/report` |
| **Method** | GET |
| **Endpoint** | `/attendance/report` |

**Request JSON (Query Parameters):**
```json
{
  "token": "string",
  "from_date": "YYYY-MM-DD",
  "to_date": "YYYY-MM-DD",
  "employee_id": "string"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "records": [
      {
        "date": "2024-12-08",
        "shift": "General",
        "day": 1,
        "time_in": "09:00:00",
        "time_out": "18:00:00",
        "work_hours": "09:00",
        "late_arrival": "00:00",
        "approved_hours": "00:00",
        "remarks": "",
        "is_absent": false,
        "check_in_location": {
          "latitude": 24.8585,
          "longitude": 67.0500,
          "address": "Office Building, Karachi",
          "landmark": "Near Dolmen Mall"
        },
        "check_out_location": {
          "latitude": 24.8585,
          "longitude": 67.0500,
          "address": "Office Building, Karachi",
          "landmark": "Near Dolmen Mall"
        }
      }
    ]
  }
}
```

**Remarks:** Fetches attendance records for a date range with location details for each check-in/check-out.

---

### Get Attendance Summary

| Field | Value |
|-------|-------|
| **Screen Name** | Attendance Summary Section |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/summary` |
| **Method** | GET |
| **Endpoint** | `/attendance/summary` |

**Request JSON (Query Parameters):**
```json
{
  "token": "string",
  "from_date": "YYYY-MM-DD",
  "to_date": "YYYY-MM-DD",
  "employee_id": "string"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "casual_leave": 2,
    "earned_leave": 10,
    "medical_leave": 5,
    "compensatory_leave": 0,
    "sick_leave": 3,
    "loss_of_pay": 0,
    "absent": 1,
    "outdoor_duty": 2,
    "approved_extra_work": 5,
    "late_count": 3,
    "total_working_days": 22,
    "present_days": 19
  }
}
```

**Remarks:** Provides summary statistics for attendance including various leave types and late counts.

---

### GeoFence Check-in (Automatic)

| Field | Value |
|-------|-------|
| **Screen Name** | GeoFence Service (Background) |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/check-in` |
| **Method** | POST |
| **Endpoint** | `/attendance/check-in` |

**Request JSON:**
```json
{
  "automatic": true,
  "employee_id": "string",
  "location": {
    "latitude": "number",
    "longitude": "number",
    "accuracy": "number",
    "timestamp": "ISO8601 datetime string"
  },
  "geofence_status": {
    "is_inside": true,
    "distance_meters": "number",
    "location_quality": "high | good | poor",
    "consecutive_readings": "number"
  },
  "note": "string (optional)"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": "Automatic check-in successful"
  },
  "body": {
    "attendance_id": "ATT-1702056789123",
    "marked_at": "2024-12-08T09:00:00Z"
  }
}
```

**Remarks:** Automatic attendance marking when user enters the geofenced office area.

---

## Leave APIs

### Get Leave Balances

| Field | Value |
|-------|-------|
| **Screen Name** | Leave Balance Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/leave_data/{card_no}` |
| **Method** | GET |
| **Endpoint** | `/leave_data/{card_no}` |

**Request:** Path parameter `card_no` (e.g., `/leave_data/50202309.1.2`)

**Response JSON:**
```json
{
  "body": {
    "items": [
      {
        "emp_pk": 50202309,
        "card_no": 50202309,
        "emp_name": "MUHAMMAD ZOHAIB FAROOQUI",
        "department": "IT",
        "year": 2025,
        "compc": 1,
        "brnch": 2,
        "leave_type_pk": 1,
        "leave_type": "CL",
        "leave_desc": "CASUAL LEAVE",
        "previous_bal": 0,
        "new_entitled": 0,
        "total": 10,
        "allowd": 10,
        "total_available": 10,
        "availed": 0,
        "balance": 10
      },
      {
        "emp_pk": 50202309,
        "card_no": 50202309,
        "emp_name": "MUHAMMAD ZOHAIB FAROOQUI",
        "department": "IT",
        "year": 2025,
        "compc": 1,
        "brnch": 2,
        "leave_type_pk": 2,
        "leave_type": "ML",
        "leave_desc": "MEDICAL LEAVE",
        "previous_bal": 0,
        "new_entitled": 0,
        "total": 8,
        "allowd": 8,
        "total_available": 8,
        "availed": 0,
        "balance": 8
      },
      {
        "emp_pk": 50202309,
        "card_no": 50202309,
        "emp_name": "MUHAMMAD ZOHAIB FAROOQUI",
        "department": "IT",
        "year": 2025,
        "compc": 1,
        "brnch": 2,
        "leave_type_pk": 3,
        "leave_type": "EL",
        "leave_desc": "EARNED LEAVE",
        "previous_bal": 0,
        "new_entitled": 0,
        "total": 60,
        "allowd": 60,
        "total_available": 60,
        "availed": 5.5,
        "balance": 54.5
      }
    ]
  }
}
```

**Remarks:** 
- Fetches all leave type balances for the employee using `card_no` as path parameter
- Response uses ORDS REST API format with `body.items` array
- Balance can be a decimal value (e.g., 54.5 for half-day leaves)
- Used by both Leave Balance Screen and Dashboard (for graphs)

---

### Get Leave Requests

| Field | Value |
|-------|-------|
| **Screen Name** | Leave History Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/leave/applications` |
| **Method** | GET |
| **Endpoint** | `/leave/applications` |

**Request JSON (Query Parameters):**
```json
{
  "token": "string",
  "employee_id": "string",
  "status": "all | pending | approved | rejected (optional)"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "requests": [
      {
        "id": "LEV-001",
        "type": "Casual Leave",
        "from_date": "2024-12-10",
        "to_date": "2024-12-11",
        "days": 2,
        "half_day": false,
        "reason": "Personal work",
        "status": "pending",
        "applied_on": "2024-12-08T10:00:00Z",
        "approved_by": null,
        "approved_on": null,
        "remarks": null
      }
    ]
  }
}
```

**Remarks:** Fetches all leave applications with their status.

---

### Submit Leave Request

| Field | Value |
|-------|-------|
| **Screen Name** | Apply Leave Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/leave/applications` |
| **Method** | POST |
| **Endpoint** | `/leave/applications` |

**Request JSON:**
```json
{
  "token": "string",
  "type": "CL | EL | ML | SL | CP | LWP",
  "from_date": "YYYY-MM-DD",
  "to_date": "YYYY-MM-DD",
  "half_day": false,
  "half_day_type": "first_half | second_half (if half_day is true)",
  "reason": "string"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": "Leave request submitted successfully"
  },
  "body": {
    "request_id": "LEV-002",
    "status": "pending"
  }
}
```

**Remarks:** Submits a new leave application for approval.

---

## Profile APIs

### Get Employee Profile

| Field | Value |
|-------|-------|
| **Screen Name** | Profile Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/employee/profile` |
| **Method** | GET |
| **Endpoint** | `/employee/profile` |

**Request JSON (Query Parameters):**
```json
{
  "token": "string",
  "employee_id": "string"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "emp_pk": 106,
    "emp_no": "F-84",
    "emp_name": "FURQAN HASAN",
    "email": "furqan.hasan@company.com",
    "phone": "3458000041",
    "nic_no": "42201-1129652-9",
    "date_of_birth": "1990-05-15",
    "date_of_join": "2019-11-21",
    "designation": "DY. GENERAL MANAGER",
    "department": "IT",
    "branch": "Head Office",
    "company": "KARACHI",
    "reporting_to": {
      "emp_pk": 105,
      "emp_name": "ALTAF HUSSAIN",
      "designation": "GENERAL MANAGER",
      "phone": "3008228498"
    },
    "emergency_contact": {
      "name": "Contact Name",
      "relation": "Spouse",
      "phone": "0300XXXXXXX"
    }
  }
}
```

**Remarks:** Fetches complete employee profile information.

---

## Notification APIs

### Get Notifications

| Field | Value |
|-------|-------|
| **Screen Name** | Notifications Drawer |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/notifications` |
| **Method** | GET |
| **Endpoint** | `/notifications` |

**Request JSON (Query Parameters):**
```json
{
  "token": "string",
  "employee_id": "string",
  "page": 1,
  "limit": 20
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": ""
  },
  "body": {
    "notifications": [
      {
        "id": "NOT-001",
        "title": "Leave Approved",
        "message": "Your casual leave request for Dec 10-11 has been approved",
        "type": "leave_approval",
        "is_read": false,
        "created_at": "2024-12-08T14:30:00Z",
        "action_url": "/leave/details/LEV-001"
      }
    ],
    "unread_count": 5,
    "total_count": 25
  }
}
```

**Remarks:** Fetches paginated notifications for the user.

---

### Mark Notification Read

| Field | Value |
|-------|-------|
| **Screen Name** | Notifications Drawer |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/notifications/{id}/read` |
| **Method** | PUT |
| **Endpoint** | `/notifications/{id}/read` |

**Request JSON:**
```json
{
  "token": "string"
}
```

**Response JSON:**
```json
{
  "header": {
    "code": 100,
    "status": "success",
    "message": "Notification marked as read"
  }
}
```

**Remarks:** Marks a specific notification as read.

---

## Face Verification APIs

### Register Face

| Field | Value |
|-------|-------|
| **Screen Name** | Face Enrollment Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/register` |
| **Method** | POST |
| **Endpoint** | `/face/register` |

**Request JSON:**
```json
{
  "employee_id": "STRING",
  "embedding": [0.123, 0.456, ...],
  "created_at": "ISO8601"
}
```

**Response JSON (Success):**
```json
{
  "body": {
    "status": "SUCCESS",
    "employee_id": "STRING",
    "already_registered": false
  }
}
```

**Response JSON (Already Registered - 409):**
```json
{
  "body": {
    "status": "CONFLICT",
    "message": "Face already registered for this employee",
    "already_registered": true
  }
}
```

**Remarks:** 
- Registers facial embeddings for an employee
- Returns 409 Conflict if face is already registered
- Returns 404 if endpoint not implemented yet

---

### Verify Face

| Field | Value |
|-------|-------|
| **Screen Name** | Face Verification Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/verify` |
| **Method** | POST |
| **Endpoint** | `/face/verify` |

**Request JSON:**
```json
{
  "employee_id": "STRING",
  "embedding": [0.123, 0.456, ...]
}
```

**Response JSON (Success - Match):**
```json
{
  "body": {
    "is_match": true,
    "confidence": 0.95,
    "message": "Face verified successfully"
  }
}
```

**Response JSON (No Match):**
```json
{
  "body": {
    "is_match": false,
    "confidence": 0.45,
    "message": "Face does not match registered face"
  }
}
```

**Response JSON (Not Registered - 404):**
```json
{
  "body": {
    "is_match": false,
    "confidence": 0.0,
    "message": "Face not registered for this employee"
  }
}
```

**Remarks:** 
- Verifies live face embedding against stored face for an employee
- Returns match status and confidence score (0.0 to 1.0)
- Confidence threshold typically 0.75 for verification

---

### Check Face Registration Status

| Field | Value |
|-------|-------|
| **Screen Name** | Profile / Face Enrollment Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/status/{employee_id}` |
| **Method** | GET |
| **Endpoint** | `/face/status/{employee_id}` |

**Request:** Path parameter `employee_id`

**Response JSON (Registered):**
```json
{
  "body": {
    "is_registered": true,
    "employee_id": "STRING",
    "registered_at": "ISO8601"
  }
}
```

**Response JSON (Not Registered - 404):**
```json
{
  "body": {
    "is_registered": false,
    "employee_id": "STRING"
  }
}
```

**Remarks:** 
- Checks if face is registered for an employee
- Returns 404 if face not registered (treated as false)
- Used to determine if enrollment is needed

---

### Delete Face Registration

| Field | Value |
|-------|-------|
| **Screen Name** | Profile Screen |
| **URL** | `http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/delete/{employee_id}` |
| **Method** | DELETE |
| **Endpoint** | `/face/delete/{employee_id}` |

**Request:** Path parameter `employee_id`

**Response JSON (Success):**
```json
{
  "body": {
    "status": "SUCCESS",
    "message": "Face registration deleted successfully"
  }
}
```

**Response JSON (Not Found - 404):**
```json
{
  "body": {
    "status": "NOT_FOUND",
    "message": "Face registration not found (may already be deleted)"
  }
}
```

**Remarks:** 
- Deletes face registration for an employee
- Returns 404 if face not registered (treated as successful deletion)
- Used when user wants to re-enroll face

---

## Error Codes

| Code | Status | Description |
|------|--------|-------------|
| 100 | success | Request processed successfully |
| 400 | error | Bad request - Invalid parameters |
| 401 | error | Unauthorized - Invalid or expired token |
| 403 | error | Forbidden - Access denied |
| 404 | error | Not found - Resource doesn't exist |
| 500 | error | Internal server error |

### Biometric Error Codes
| Error Code | Description |
|------------|-------------|
| BIO_NOT_AVAILABLE | Biometric not available on device |
| BIO_NOT_ENROLLED | User hasn't enrolled biometrics |
| BIO_VERIFY_FAILED | Biometric verification failed |
| BIO_LOCKED_OUT | Too many failed attempts |

### Location Error Codes
| Error Code | Description |
|------------|-------------|
| LOC_PERMISSION_DENIED | Location permission not granted |
| LOC_SERVICE_DISABLED | Location services are disabled |
| LOC_MOCK_DETECTED | Mock location detected |
| LOC_OUTSIDE_GEOFENCE | User is outside office geofence |

---

## Data Types Reference

| Type | Format | Example |
|------|--------|---------|
| datetime | ISO8601 | `2024-12-08T09:30:00Z` |
| date | YYYY-MM-DD | `2024-12-08` |
| time | HH:MM:SS | `09:30:00` |
| phone | Number(10) | `3458000041` |
| coordinates | Decimal | `24.858510` |
| token | JWT String | `eyJhbGciOiJIUzI1...` |

---

## Notes

1. **Authentication**: All API calls (except login) require a valid Bearer token in the Authorization header.
2. **Location Data**: For biometric attendance, the app collects comprehensive location data including coordinates, address, and nearby landmarks for audit and verification purposes.
3. **Biometric Types**: The app supports both fingerprint and face recognition, depending on device capabilities.
4. **Geofence**: Automatic attendance marking is triggered when the user enters the predefined office geofence area.
5. **Offline Support**: The app queues attendance entries when offline and syncs when connectivity is restored.

---

## API Mapping Table (TSV Format)

| Screen Name | URL | Method | Endpoint | Request (Query / Body) | Response JSON | Remarks |
|-------------|-----|--------|----------|----------------------|---------------|---------|
| Sign In Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/login | POST | /login | `{"username": "3458000041", "password": "oracle1"}` | `{"body": {"status": "SUCCESS", "card_no": "STRING"}}` | User authentication using phone number and passcode (no token) |
| Dashboard | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/data/{card_no} | GET | /data/{card_no} |  | `{"body": {"emp_pk": "NUMBER", "card_no": "STRING", "emp_no": "STRING", "emp_name": "STRING", "date_of_join": "ISO8601", "nic_no": "STRING", "designation": "STRING", "department": "STRING", "compcnm": "STRING", "compc": "NUMBER", "branch": "NUMBER", "brnchnm": "STRING", "hod": "NUMBER", "hod_nm": "STRING"}}` | Employee dashboard information |
| Biometric Attendance Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/biometric | POST | /attendance/biometric | `{"emp_pk": "NUMBER", "attendance_type": "check_in\|check_out", "biometric_type": "fingerprint\|face", "location": {"latitude": "NUMBER", "longitude": "NUMBER", "accuracy": "NUMBER", "timestamp": "ISO8601", "address": "STRING", "street_address": "STRING", "locality": "STRING", "sub_locality": "STRING", "postal_code": "STRING", "country": "STRING", "nearest_landmark": "STRING", "famous_place": "STRING", "distance_to_landmark": "NUMBER", "formatted_address": "STRING"}, "timestamp": "ISO8601", "device_id": "STRING", "device_model": "STRING", "app_version": "STRING"}` | `{"body": {"attendance_id": "STRING", "marked_at": "ISO8601", "location_verified": true, "biometric_verified": true}}` | Marks biometric attendance with location and device info |
| Attendance History Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/report | GET | /attendance/report | emp_pk=NUMBER&from_date=YYYY-MM-DD&to_date=YYYY-MM-DD | `{"body": {"records": [{"date": "YYYY-MM-DD", "shift": "STRING", "day": 1, "time_in": "HH:MM:SS", "time_out": "HH:MM:SS", "work_hours": "HH:MM", "late_arrival": "HH:MM", "approved_hours": "HH:MM", "remarks": "STRING", "is_absent": false, "check_in_location": {"latitude": "NUMBER", "longitude": "NUMBER", "address": "STRING", "landmark": "STRING"}, "check_out_location": {"latitude": "NUMBER", "longitude": "NUMBER", "address": "STRING", "landmark": "STRING"}}]}}` | Attendance records by date range |
| Attendance Summary | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/attendance/summary | GET | /attendance/summary | emp_pk=NUMBER&from_date=YYYY-MM-DD&to_date=YYYY-MM-DD | `{"body": {"casual_leave": 2, "earned_leave": 10, "medical_leave": 5, "compensatory_leave": 0, "sick_leave": 3, "loss_of_pay": 0, "absent": 1, "outdoor_duty": 2, "approved_extra_work": 5, "late_count": 3, "total_working_days": 22, "present_days": 19}}` | Attendance and leave summary |
| Leave Balance Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/leave_data/{card_no} | GET | /leave_data/{card_no} |  | `{"body": {"items": [{"emp_pk": "NUMBER", "card_no": "NUMBER", "emp_name": "STRING", "department": "STRING", "year": "NUMBER", "compc": "NUMBER", "brnch": "NUMBER", "leave_type_pk": "NUMBER", "leave_type": "STRING", "leave_desc": "STRING", "previous_bal": "NUMBER", "new_entitled": "NUMBER", "total": "NUMBER", "allowd": "NUMBER", "total_available": "NUMBER", "availed": "NUMBER", "balance": "NUMBER"}]}}` | Employee leave balances using card_no. Response in ORDS format with items array. Balance can be decimal (e.g., 54.5). Used by Leave Balance Screen and Dashboard graphs |
| Leave History Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/leave/applications | GET | /leave/applications | emp_pk=NUMBER&status=all\|pending\|approved\|rejected | `{"body": {"requests": [{"id": "STRING", "type": "STRING", "from_date": "YYYY-MM-DD", "to_date": "YYYY-MM-DD", "days": "NUMBER", "half_day": false, "reason": "STRING", "status": "STRING", "applied_on": "ISO8601", "approved_by": "STRING", "approved_on": "ISO8601", "remarks": "STRING"}]}}` | Leave application history |
| Apply Leave Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/leave/applications | POST | /leave/applications | `{"emp_pk": "NUMBER", "type": "CL\|EL\|ML\|SL\|CP\|LWP", "from_date": "YYYY-MM-DD", "to_date": "YYYY-MM-DD", "half_day": false, "half_day_type": "first_half\|second_half", "reason": "STRING"}` | `{"body": {"request_id": "STRING", "status": "pending"}}` | Submit leave request |
| Profile Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/employee/profile | GET | /employee/profile | emp_pk=NUMBER | `{"body": {"emp_pk": "NUMBER", "emp_no": "STRING", "emp_name": "STRING", "email": "STRING", "phone": "STRING", "nic_no": "STRING", "date_of_birth": "YYYY-MM-DD", "date_of_join": "YYYY-MM-DD", "designation": "STRING", "department": "STRING", "branch": "STRING", "company": "STRING", "reporting_to": {"emp_pk": "NUMBER", "emp_name": "STRING", "designation": "STRING", "phone": "STRING"}, "emergency_contact": {"name": "STRING", "relation": "STRING", "phone": "STRING"}}}` | Employee complete profile |
| Notifications Drawer | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/notifications | GET | /notifications | emp_pk=NUMBER&page=NUMBER&limit=NUMBER | `{"body": {"notifications": [{"id": "STRING", "title": "STRING", "message": "STRING", "type": "STRING", "is_read": false, "created_at": "ISO8601", "action_url": "STRING"}], "unread_count": "NUMBER", "total_count": "NUMBER"}}` | Paginated notifications |
| Mark Notification Read | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/notifications/{id}/read | PUT | /notifications/{id}/read | `{"emp_pk": "NUMBER"}` | `{"success": true}` | Mark notification as read |
| Face Enrollment Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/register | POST | /face/register | `{"employee_id": "STRING", "embedding": [0.123, 0.456, ...], "created_at": "ISO8601"}` | `{"body": {"status": "SUCCESS", "employee_id": "STRING", "already_registered": false}}` | Register facial embeddings for employee. Returns 409 if already registered, 404 if endpoint not implemented |
| Face Verification Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/verify | POST | /face/verify | `{"employee_id": "STRING", "embedding": [0.123, 0.456, ...]}` | `{"body": {"is_match": true, "confidence": 0.95, "message": "Face verified successfully"}}` | Verify live face against stored face. Returns match status and confidence (0.0-1.0). Threshold typically 0.75 |
| Profile / Face Enrollment Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/status/{employee_id} | GET | /face/status/{employee_id} |  | `{"body": {"is_registered": true, "employee_id": "STRING", "registered_at": "ISO8601"}}` | Check if face is registered. Returns 404 if not registered (treated as false) |
| Profile Screen | http://lms.yousufdewan.com:8080/ords/ws_tms/empdata/face/delete/{employee_id} | DELETE | /face/delete/{employee_id} |  | `{"body": {"status": "SUCCESS", "message": "Face registration deleted successfully"}}` | Delete face registration. Returns 404 if not registered (treated as successful) |

