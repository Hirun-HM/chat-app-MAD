#!/bin/bash

echo "🧪 Testing WhatsApp QR Code Feature"
echo "===================================="

# Test QR code generation for all users
echo ""
echo "📱 Testing QR Code Generation for all users:"
echo "-------------------------------------------"
for i in {1..5}; do
    echo "User $i:"
    response=$(curl -s "http://localhost:8000/api/qr-code/$i")
    
    if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        name=$(echo "$response" | jq -r '.contactData.name')
        phone=$(echo "$response" | jq -r '.contactData.phone')
        whatsapp_url=$(echo "$response" | jq -r '.whatsappUrl')
        echo "  ✅ $name - $phone"
        echo "  📱 WhatsApp URL: $whatsapp_url"
    else
        echo "  ❌ Failed to generate QR code for user $i"
        echo "  Error: $response"
    fi
    echo ""
done

# Test phone number lookup
echo ""
echo "🔍 Testing Phone Number Lookup:"
echo "------------------------------"
phones=("+94719162128" "+94741377070" "+94764532890" "+94774087556" "+94772147171")
for phone in "${phones[@]}"; do
    echo "Looking up: $phone"
    response=$(curl -s "http://localhost:8000/api/users/phone/$phone")
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        name=$(echo "$response" | jq -r '.name')
        id=$(echo "$response" | jq -r '.id')
        echo "  ✅ Found: $name (ID: $id)"
    else
        echo "  ❌ User not found"
        echo "  Error: $response"
    fi
    echo ""
done

# Test chat creation
echo ""
echo "💬 Testing Chat Creation:"
echo "------------------------"
response=$(curl -s -X POST "http://localhost:8000/api/chats/individual" \
  -H "Content-Type: application/json" \
  -d '{"sourceId": 1, "targetId": 2}')

if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
    echo "✅ Chat creation successful"
    chat_id=$(echo "$response" | jq -r '.chatId')
    echo "Response: Chat ID $chat_id - $(echo "$response" | jq -r '.message')"
else
    echo "❌ Chat creation failed"
    echo "Error: $response"
fi

echo ""
echo "🎉 Test completed!"
echo "================="
echo ""
echo "Features implemented:"
echo "✅ WhatsApp-compatible QR code generation"
echo "✅ Sri Lankan phone number format (+94 xxx xxx xxx)"
echo "✅ Phone number lookup API"
echo "✅ Individual chat creation API"
echo "✅ QR scanner screen (Flutter)"
echo "✅ Contact sharing screen (Flutter)"
echo ""
echo "Next steps for complete functionality:"
echo "- Run the Flutter app and test UI interactions"
echo "- Scan QR codes to verify WhatsApp link opening"
echo "- Test adding contacts through QR scanning"
