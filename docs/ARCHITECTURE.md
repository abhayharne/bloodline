# Architecture

```
 Flutter app (requester | donor | bank)
   |-- Nexconn Chat SDK + Chat UI: connect, ChannelPage, ChatPage, messages
   |-- REST --> Go API
                 |-- SQLite: users, bank_stock, requests, request_members
                 |-- Nexconn server API: user tokens, create group, add members, system messages
```

## Principles
- Server is the authority for who is in which room.
- App talks to Nexconn only for messaging; everything else goes through the API.
- One request = one channel (`channel_id` stored on the request).

## Core flow
1. Requester `POST /requests`.
2. API stores the request, runs matching (see DATA_MODEL.md), creates the room, adds requester and the best banks.
3. Matched donors see the request in `GET /requests` (and an in-app banner).
4. Donor `POST /requests/{id}/accept` -> API adds donor to the room -> app opens `ChatPage`.
5. People coordinate in chat (text, photos, location pin).
6. Requester `POST /requests/{id}/fulfill` -> API posts a system message, closes the room, status=fulfilled.

## Auth
App JWT (HS256) issued by signup/login, sent as `Authorization: Bearer <jwt>`.
Login response also includes `nexconn_token` used by the app to connect to chat.

## Roles
| Role | Can |
|---|---|
| requester | create request, see own, fulfill own |
| donor | see matching open requests, accept |
| bank | edit stock, see open requests in range, accept |

## Environments
Laptop runs the API on :8080; phones reach it by LAN IP or a tunnel. App base URL is configurable on the login screen (dev setting).
