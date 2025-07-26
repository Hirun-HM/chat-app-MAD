#!/bin/bash

echo "🎯 WhatsApp-like Behavior Test"
echo "=============================="
echo ""

# Function to count chats
count_chats() {
    local user_id=$1
    curl -s -X GET "http://localhost:8000/api/chats/$user_id" -H "Content-Type: application/json" | jq length 2>/dev/null || echo "0"
}

# Function to create chat
create_chat() {
    local source_id=$1
    local target_id=$2
    curl -s -X POST "http://localhost:8000/api/chats/individual" \
        -H "Content-Type: application/json" \
        -d "{\"sourceId\": $source_id, \"targetId\": $target_id}" | jq -r '.chatId // "null"'
}

# Function to send message
send_message() {
    local chat_id=$1
    local sender_id=$2
    local message=$3
    curl -s -X POST "http://localhost:8000/api/messages" \
        -H "Content-Type: application/json" \
        -d "{\"chatId\": $chat_id, \"senderId\": $sender_id, \"messageText\": \"$message\", \"messageType\": \"text\"}" | jq -r '.success // false'
}

echo "📊 Initial State:"
INITIAL_COUNT=$(count_chats 1)
echo "User 1 has $INITIAL_COUNT chats"

echo ""
echo "🆕 Creating new chat (User 1 → User 4):"
NEW_CHAT_ID=$(create_chat 1 4)
echo "New chat ID: $NEW_CHAT_ID"

echo ""
echo "📋 After chat creation (should NOT appear in list):"
AFTER_CREATE_COUNT=$(count_chats 1)
echo "User 1 has $AFTER_CREATE_COUNT chats"

if [ "$AFTER_CREATE_COUNT" -eq "$INITIAL_COUNT" ]; then
    echo "✅ CORRECT: Chat not visible without messages"
else
    echo "❌ WRONG: Chat appeared without messages"
fi

echo ""
echo "💬 Sending first message:"
MESSAGE_SENT=$(send_message $NEW_CHAT_ID 1 "Hi! This is our first message.")
echo "Message sent: $MESSAGE_SENT"

echo ""
echo "📋 After sending message (should NOW appear in list):"
AFTER_MESSAGE_COUNT=$(count_chats 1)
echo "User 1 has $AFTER_MESSAGE_COUNT chats"

if [ "$AFTER_MESSAGE_COUNT" -gt "$INITIAL_COUNT" ]; then
    echo "✅ CORRECT: Chat appeared after first message"
else
    echo "❌ WRONG: Chat still not visible after message"
fi

echo ""
echo "🎉 Test Complete!"
echo "Initial: $INITIAL_COUNT → After create: $AFTER_CREATE_COUNT → After message: $AFTER_MESSAGE_COUNT"
