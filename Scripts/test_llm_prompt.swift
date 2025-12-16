#!/usr/bin/env swift

// Run this script from the project root:
// swift Scripts/test_llm_prompt.swift
//
// Note: This requires the full app to be built first
// and the model to be downloaded.

import Foundation

print("""
================================================================================
LLM Prompt Test Script
================================================================================

This script tests different prompt configurations for the LLM PII detector.
Since MLX requires the Metal framework context, please run the tests
through the actual app instead.

To test prompts:
1. Build and run the app: swift build -c release && .build/release/PasteFence
2. Copy this test text to clipboard:

---
Contact: john.doe@example.com
Phone: 010-1234-5678
API Key: sk-abcdefghij1234567890abcdefghij1234567890abcdef
Password: secret123
IP: 192.168.1.100
---

3. Press Cmd+Shift+V
4. Check the terminal output for raw LLM response

To iterate on prompts:
- Edit Sources/PasteFence/Detectors/LLMDetector.swift
- Rebuild: swift build -c release
- Test again

================================================================================
""")
