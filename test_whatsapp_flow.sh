#!/bin/bash

echo "🎯 COMPREHENSIVE WHATSAPP-LIKE FUNCTIONALITY TEST"
echo "================================================="
echo ""

echo "📋 Testing the complete user flow:"
echo "1. Delete chat → Chat disappears from list"
echo "2. Select contact → Can message user again"
echo "3. Send message → Chat reappears in list"
echo "4. Contact selection shows real users"
echo ""

echo "🗄️ Current database state:"
echo "Users in system:"
curl -s -X GET "http://localhost:8000/api/users" -H "Content-Type: application/json" | jq -r '.[] | "├─ ID: \(.id) | Name: \(.name) | Phone: \(.phone)"'

echo ""
echo "📋 Current chats for User 1:"
curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq -r '.[] | "├─ Chat ID: \(.id) | Name: \(.name) | Type: \(.type) | Last: \(.currentMessage | .[0:40])..."'

echo ""
echo "🧪 Testing individual chat creation API:"

echo "├─ Test 1: Create chat between User 1 and User 2"
RESULT1=$(curl -s -X POST "http://localhost:8000/api/chats/individual" \
  -H "Content-Type: application/json" \
  -d '{"sourceId": 1, "targetId": 2}')
echo "│  Result: $(echo "$RESULT1" | jq -r '.message // .error') (Chat ID: $(echo "$RESULT1" | jq -r '.chatId // "N/A"'))"

echo "├─ Test 2: Create chat between User 1 and User 3" 
RESULT2=$(curl -s -X POST "http://localhost:8000/api/chats/individual" \
  -H "Content-Type: application/json" \
  -d '{"sourceId": 1, "targetId": 3}')
echo "│  Result: $(echo "$RESULT2" | jq -r '.message // .error') (Chat ID: $(echo "$RESULT2" | jq -r '.chatId // "N/A"'))"

echo "├─ Test 3: Try to create duplicate chat (should return same ID)"
RESULT3=$(curl -s -X POST "http://localhost:8000/api/chats/individual" \
  -H "Content-Type: application/json" \
  -d '{"sourceId": 1, "targetId": 2}')
echo "│  Result: $(echo "$RESULT3" | jq -r '.message // .error') (Chat ID: $(echo "$RESULT3" | jq -r '.chatId // "N/A"'))"

echo "└─ Test 4: Invalid request (same user)"
RESULT4=$(curl -s -X POST "http://localhost:8000/api/chats/individual" \
  -H "Content-Type: application/json" \
  -d '{"sourceId": 1, "targetId": 1}')
echo "   Result: $(echo "$RESULT4" | jq -r '.error // .message')"

echo ""
echo "🎯 User Flow Simulation:"
echo "├─ User 1 deletes chat with User 2"
DELETE_RESULT=$(curl -s -X DELETE "http://localhost:8000/api/chats/1/1" -H "Content-Type: application/json")
echo "│  Delete action: $(echo "$DELETE_RESULT" | jq -r '.action // .error // "Success"')"

echo "├─ Check User 1's chats after deletion"
CHATS_AFTER_DELETE=$(curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq length)
echo "│  Remaining chats: $CHATS_AFTER_DELETE"

echo "├─ User 1 creates new chat with User 2 again (via contact selection)"
NEW_CHAT=$(curl -s -X POST "http://localhost:8000/api/chats/individual" \
  -H "Content-Type: application/json" \
  -d '{"sourceId": 1, "targetId": 2}')
NEW_CHAT_ID=$(echo "$NEW_CHAT" | jq -r '.chatId')
echo "│  New chat created: ID $NEW_CHAT_ID"

echo "└─ User 1 sends message to the new chat"
MESSAGE_RESULT=$(curl -s -X POST "http://localhost:8000/api/messages" \
  -H "Content-Type: application/json" \
  -d "{
    \"chatId\": $NEW_CHAT_ID,
    \"senderId\": 1,
    \"messageText\": \"Hello again! This chat was recreated after deletion.\",
    \"messageType\": \"text\"
  }")
echo "   Message sent: $(echo "$MESSAGE_RESULT" | jq -r '.success // false')"

echo ""
echo "📋 Final chat list for User 1 (should include the new chat):"
curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq -r '.[] | "├─ \(.name) | Last: \(.currentMessage | .[0:50])... | Ticks: \(if .isLastMessageFromCurrentUser then (if .lastMessageReadByOthers then "Blue ✓✓" else "Gray ✓✓") else "None")"'

echo ""
echo "✅ WHATSAPP-LIKE FUNCTIONALITY VERIFICATION COMPLETE!"
echo ""
echo "📱 Expected Flutter App Behavior:"
echo "├─ Select Contact page shows all users from database"
echo "├─ Tapping a contact creates/finds individual chat"  
echo "├─ Deleted chats can be recreated by messaging user again"
echo "├─ New chats appear in chat list after first message"
echo "└─ All real-time updates work via Socket.IO"
echo ""
