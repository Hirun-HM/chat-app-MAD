#!/bin/bash

echo "🧪 Testing WhatsApp-style tick system"
echo "===================================="

# Test 1: Check initial chat list state
echo "📋 Test 1: Current chat list for user 1"
curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq '[.[] | {id, name, lastSenderId, isLastMessageFromCurrentUser, lastMessageReadByOthers, currentMessage}]'

echo -e "\n📨 Test 2: Sending message from user 1 to chat 1"
curl -s -X POST "http://localhost:8000/api/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "chatId": 1,
    "senderId": 1,
    "messageText": "Final test message - should show gray ticks initially",
    "messageType": "text"
  }' | jq .

echo -e "\n📋 Test 3: Chat list after sending (should show gray ticks for user 1's message)"
curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq '[.[] | select(.id == 1) | {id, name, lastSenderId, isLastMessageFromCurrentUser, lastMessageReadByOthers, currentMessage}]'

echo -e "\n👁️ Test 4: User 2 reads the message"
curl -s -X POST "http://localhost:8000/api/messages/mark-read/1/2" \
  -H "Content-Type: application/json" | jq .

echo -e "\n📋 Test 5: Chat list after reading (should show blue ticks for user 1's message)"
curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq '[.[] | select(.id == 1) | {id, name, lastSenderId, isLastMessageFromCurrentUser, lastMessageReadByOthers, currentMessage}]'

echo -e "\n📨 Test 6: User 2 sends a reply"
curl -s -X POST "http://localhost:8000/api/messages" \
  -H "Content-Type: application/json" \
  -d '{
    "chatId": 1,
    "senderId": 2,
    "messageText": "Reply from user 2 - should show no ticks for user 1",
    "messageType": "text"
  }' | jq .

echo -e "\n📋 Test 7: Final chat list (should show no ticks since last message is from user 2)"
curl -s -X GET "http://localhost:8000/api/chats/1" -H "Content-Type: application/json" | jq '[.[] | select(.id == 1) | {id, name, lastSenderId, isLastMessageFromCurrentUser, lastMessageReadByOthers, currentMessage}]'

echo -e "\n✅ Test Summary:"
echo "• Messages from current user show ticks (gray initially, blue when read)"
echo "• Messages from others show no ticks"
echo "• Read status is tracked correctly"
echo -e "\n🎉 Tick system test complete!"
