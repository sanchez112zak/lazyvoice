#!/bin/bash

echo "🎧 LazyVoice Headphone Recording Test"
echo "===================================="
echo ""

# Check if the app exists
if [ ! -f "lazyvoice.app/Contents/MacOS/lazyvoice" ]; then
    echo "❌ LazyVoice app not found. Please make sure you're in the correct directory."
    exit 1
fi

echo "🔍 Testing scenario 1: WITHOUT HEADPHONES"
echo "----------------------------------------"
echo "1. Make sure your headphones are DISCONNECTED"
echo "2. Press Enter when ready..."
read

# Test 1: Check audio devices without headphones
echo "📱 Running debug script to check audio devices..."
swift debug_audio_devices.swift > test_results_no_headphones.log 2>&1
echo "✅ Results saved to test_results_no_headphones.log"

echo ""
echo "🎯 Now testing the main app..."
echo "3. The LazyVoice app will launch in 3 seconds"
echo "4. Try recording by pressing the global hotkey (⌥+⌘+Space)"
echo "5. Speak something and see if it gets transcribed"
echo "6. Close the app when done testing"
echo ""
countdown=3
while [ $countdown -gt 0 ]; do
    echo "Starting in $countdown..."
    sleep 1
    countdown=$((countdown - 1))
done

# Launch the app
echo "🚀 Launching LazyVoice..."
./lazyvoice.app/Contents/MacOS/lazyvoice &
APP_PID=$!

echo "App launched with PID: $APP_PID"
echo "Press Enter when you're done testing without headphones..."
read

# Kill the app
kill $APP_PID 2>/dev/null || echo "App already closed"
sleep 2

echo ""
echo "🎧 Testing scenario 2: WITH HEADPHONES"
echo "--------------------------------------"
echo "1. Now CONNECT your headphones"
echo "2. Make sure they are properly connected and recognized by macOS"
echo "3. You can check this in System Settings > Sound"
echo "4. Press Enter when your headphones are connected..."
read

# Test 2: Check audio devices with headphones
echo "📱 Running debug script to check audio devices with headphones..."
swift debug_audio_devices.swift > test_results_with_headphones.log 2>&1
echo "✅ Results saved to test_results_with_headphones.log"

echo ""
echo "🎯 Now testing the main app with headphones..."
echo "5. The LazyVoice app will launch again in 3 seconds"
echo "6. Try recording by pressing the global hotkey (⌥+⌘+Space)"
echo "7. Speak something and see if it gets transcribed"
echo "8. Pay attention to whether recording works or not"
echo "9. Close the app when done testing"
echo ""
countdown=3
while [ $countdown -gt 0 ]; do
    echo "Starting in $countdown..."
    sleep 1
    countdown=$((countdown - 1))
done

# Launch the app again
echo "🚀 Launching LazyVoice with headphones..."
./lazyvoice.app/Contents/MacOS/lazyvoice &
APP_PID=$!

echo "App launched with PID: $APP_PID"
echo "Press Enter when you're done testing with headphones..."
read

# Kill the app
kill $APP_PID 2>/dev/null || echo "App already closed"
sleep 2

echo ""
echo "📊 ANALYSIS"
echo "==========="
echo "Now let's compare the results..."
echo ""

echo "🔍 Audio devices WITHOUT headphones:"
echo "------------------------------------"
grep -A 20 "Available Audio Input Devices" test_results_no_headphones.log || echo "No device info found"
echo ""

echo "🔍 Audio devices WITH headphones:"
echo "--------------------------------"
grep -A 20 "Available Audio Input Devices" test_results_with_headphones.log || echo "No device info found"
echo ""

echo "🔍 Default devices comparison:"
echo "-----------------------------"
echo "Without headphones:"
grep "Default Input Device" test_results_no_headphones.log || echo "No default device info found"
echo ""
echo "With headphones:"
grep "Default Input Device" test_results_with_headphones.log || echo "No default device info found"
echo ""

echo "🔍 Audio engine comparison:"
echo "----------------------------"
echo "Without headphones:"
grep "AVAudioEngine input node" test_results_no_headphones.log || echo "No engine info found"
echo ""
echo "With headphones:"
grep "AVAudioEngine input node" test_results_with_headphones.log || echo "No engine info found"
echo ""

echo "💡 TROUBLESHOOTING TIPS:"
echo "========================"
echo "1. Check if the default input device changes when you connect headphones"
echo "2. Look for any errors in the audio engine startup"
echo "3. Compare sample rates between the two scenarios"
echo "4. If recording fails with headphones, try these solutions:"
echo "   - Go to System Settings > Sound > Input"
echo "   - Manually select 'MacBook Pro Microphone' as input"
echo "   - Try disconnecting and reconnecting headphones"
echo "   - Restart LazyVoice after changing audio settings"
echo ""

echo "📋 Full logs are available in:"
echo "- test_results_no_headphones.log"
echo "- test_results_with_headphones.log"
echo ""
echo "🔧 If the issue persists, the enhanced AudioManager should now:"
echo "- Reset the audio engine when starting recording"
echo "- Log detailed device information for debugging"
echo "- Better handle device changes when headphones are connected" 