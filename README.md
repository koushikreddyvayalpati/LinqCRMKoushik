# Linq CRM Integration Demo

I built this to show how Linq could integrate with a customer's CRM system. Used Rails because it's fast to build APIs with and most people are comfortable with it.
##Video Presentation Demo
Link: https://www.loom.com/share/a4e27c8966ae471aa1c591d8e738bb03?sid=94859d58-4f7d-4f00-993d-e510e08f63e0
## What it does

Someone scans a QR code at an event → contact gets saved to your database → pushes to their CRM automatically. Pretty straightforward.

The demo uses "AcmeCRM" as a fake external CRM, but the same pattern works for Salesforce, HubSpot, whatever.

## Quick start

You'll need Ruby (3.4+) and Rails. If you have those:

```bash
cd linq_crm_integration
bundle install
rails db:migrate
rails server
```

Then go to `http://localhost:3000/demo.html` to see it working.

## What's in the demo

**Authentication stuff**: JWT tokens that work like real auth but simplified for demo purposes

**Contact creation**: Form that takes contact info, normalizes it, saves locally, and syncs with the fake CRM

**Load testing**: Button that simulates 100 people scanning QR codes at the same time (because customers always ask about scale)

**Real-time metrics**: Shows response times, success rates, all that good stuff customers want to see

## How the integration works

```
User scans QR → Rails API → Normalizes data → Saves locally → Pushes to CRM
                     ↓
             If CRM is down, we queue it for later
```

The tricky part is field mapping. Every CRM calls things differently:
- We use `first_name`, AcmeCRM uses `acme_first_name`  
- We use `email`, they use `acme_email`
- etc.

Built a service that handles all that translation automatically.

## API endpoints

**POST /api/v1/auth** - Get a JWT token
```json
{
  "email": "demo@linq.app",
  "name": "Your Name",
  "company": "Your Company"
}
```

**POST /api/v1/contacts** - Create a contact
```json
{
  "first_name": "John",
  "last_name": "Doe", 
  "email": "john@example.com",
  "phone": "+1-555-123-4567",
  "company": "Their Company",
  "title": "VP of Sales"
}
```

**GET /api/v1/contacts** - List all contacts

All endpoints need the JWT token in the Authorization header.

## Testing it

The demo page has everything you need:

1. **Get a token** - Click the auth button
2. **Create some contacts** - Fill out the form, or use the load test
3. **See the results** - Contact list updates in real time

The load test is pretty cool - simulates a conference where 100 people scan QR codes simultaneously. Shows it can handle real-world usage.

## Production considerations

This is a demo, but it's built with real patterns:

- **Error handling**: If the external CRM is down, we save locally and sync later
- **Rate limiting**: Respects CRM API limits  
- **Retries**: Automatically retries failed requests
- **Validation**: Makes sure data is clean before sending anywhere
- **Background jobs**: Heavy lifting happens async so users don't wait

## File structure

```
app/
  controllers/api/v1/     # API endpoints
  models/                 # Contact model with CRM mapping
  services/               # AcmeCRM integration logic
  jobs/                   # Background sync jobs
public/demo.html          # Demo interface
```

## What I'd improve with more time

- **Better error messages** - Right now they're pretty generic
- **Webhook support** - So the CRM can push updates back to us  
- **Field mapping UI** - Let customers configure their own field mappings
- **More CRM connectors** - This is just AcmeCRM, but the pattern works for any API
- **Bulk operations** - Handle importing thousands of contacts at once
- **Monitoring/alerting** - Know when sync jobs are failing

## Why this approach

**Rails**: Fast to build, customers trust it, good ecosystem for API integrations

**SQLite**: Simple for demos, easy to see the data, no setup required

**JWT auth**: Industry standard, works with any frontend, easy to integrate

**Background jobs**: User doesn't wait for external API calls, can retry failures

**Field mapping**: Every CRM is different, this makes it adaptable

# LinqCRMKoushik
