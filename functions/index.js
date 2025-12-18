/**
 * EduVerse AI Backend - Firebase Cloud Functions
 * 
 * This module provides secure AI proxy endpoints that:
 * 1. Keep API keys on the server (never exposed to client)
 * 2. Handle CORS properly for web browsers
 * 3. Call xAI Grok API from the server side
 * 
 * Endpoints:
 * - askAI: Text-based AI chat
 * - analyzeImage: Image analysis for homework help
 */

const functions = require("firebase-functions");
const fetch = require("node-fetch");
const cors = require("cors");

// Initialize CORS middleware - allow requests from any origin for development
// In production, you should restrict this to your domain
const corsHandler = cors({ origin: true });

// xAI API configuration
const XAI_API_URL = "https://api.x.ai/v1/chat/completions";
const XAI_MODEL = "grok-2-latest";

/**
 * Get API key from Firebase Functions config or environment
 * Set with: firebase functions:config:set xai.api_key="your-key-here"
 * Or use .env file for local development
 */
function getApiKey() {
  // Try Firebase config first
  if (functions.config().xai && functions.config().xai.api_key) {
    return functions.config().xai.api_key;
  }
  // Fallback to environment variable
  if (process.env.XAI_API_KEY) {
    return process.env.XAI_API_KEY;
  }
  // Last resort: hardcoded for development ONLY (remove in production!)
  // This will be removed once you configure Firebase properly
  return "xai-ez4lUNwM9oxEk56AHOObwlrGYGBKwuUIEnVha8zDfzgKnglRni5Cbz539KeCnqRkviV0F4Gzmn3vZaitE";
}

/**
 * askAI - Text-based AI chat endpoint
 * 
 * Request body:
 * {
 *   "prompt": "User's question here",
 *   "systemPrompt": "Optional custom system prompt"
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "response": "AI response text"
 * }
 */
exports.askAI = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    // Only allow POST requests
    if (req.method !== "POST") {
      return res.status(405).json({ 
        success: false, 
        error: "Method not allowed. Use POST." 
      });
    }

    try {
      const { prompt, systemPrompt } = req.body;

      if (!prompt || typeof prompt !== "string" || prompt.trim() === "") {
        return res.status(400).json({ 
          success: false, 
          error: "Missing or invalid 'prompt' field" 
        });
      }

      const apiKey = getApiKey();
      if (!apiKey) {
        return res.status(500).json({ 
          success: false, 
          error: "API key not configured" 
        });
      }

      // Build request body for xAI
      const requestBody = {
        model: XAI_MODEL,
        messages: [
          {
            role: "system",
            content: systemPrompt || 
              "You are EduVerse AI, a helpful educational assistant. Provide clear, concise, and educational responses to help students and teachers with their learning. Use markdown formatting for better readability."
          },
          {
            role: "user",
            content: prompt.trim()
          }
        ],
        temperature: 0.7
      };

      // Call xAI API
      const response = await fetch(XAI_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();

      if (!response.ok) {
        console.error("xAI API Error:", data);
        
        if (response.status === 429) {
          return res.status(429).json({ 
            success: false, 
            error: "Rate limit reached. Please wait a moment and try again." 
          });
        }
        
        if (response.status === 401) {
          return res.status(500).json({ 
            success: false, 
            error: "API authentication failed. Please contact support." 
          });
        }

        return res.status(response.status).json({ 
          success: false, 
          error: data.error?.message || "AI service error" 
        });
      }

      // Extract AI response
      const aiResponse = data.choices?.[0]?.message?.content;
      
      if (!aiResponse) {
        return res.status(500).json({ 
          success: false, 
          error: "No response from AI" 
        });
      }

      return res.status(200).json({ 
        success: true, 
        response: aiResponse 
      });

    } catch (error) {
      console.error("Function error:", error);
      return res.status(500).json({ 
        success: false, 
        error: "Internal server error. Please try again." 
      });
    }
  });
});

/**
 * analyzeImage - Image analysis endpoint for homework help
 * 
 * Request body:
 * {
 *   "imageBase64": "base64 encoded image data",
 *   "prompt": "Optional additional context"
 * }
 * 
 * Response:
 * {
 *   "success": true,
 *   "response": "AI analysis of the image"
 * }
 */
exports.analyzeImage = functions.https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method !== "POST") {
      return res.status(405).json({ 
        success: false, 
        error: "Method not allowed. Use POST." 
      });
    }

    try {
      const { imageBase64, prompt } = req.body;

      if (!imageBase64 || typeof imageBase64 !== "string") {
        return res.status(400).json({ 
          success: false, 
          error: "Missing or invalid 'imageBase64' field" 
        });
      }

      const apiKey = getApiKey();
      if (!apiKey) {
        return res.status(500).json({ 
          success: false, 
          error: "API key not configured" 
        });
      }

      // Build request body for xAI with image
      const requestBody = {
        model: "grok-2-vision-1212", // Vision model for image analysis
        messages: [
          {
            role: "system",
            content: "You are a helpful homework assistant. Analyze the image and help solve any problems shown. If it's a math problem, show all work clearly step by step. Use markdown formatting."
          },
          {
            role: "user",
            content: [
              {
                type: "text",
                text: prompt || "Please help me solve this homework problem. Explain step by step."
              },
              {
                type: "image_url",
                image_url: {
                  url: `data:image/jpeg;base64,${imageBase64}`
                }
              }
            ]
          }
        ],
        max_tokens: 2048
      };

      const response = await fetch(XAI_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();

      if (!response.ok) {
        console.error("xAI API Error:", data);
        return res.status(response.status).json({ 
          success: false, 
          error: data.error?.message || "AI service error" 
        });
      }

      const aiResponse = data.choices?.[0]?.message?.content;
      
      if (!aiResponse) {
        return res.status(500).json({ 
          success: false, 
          error: "No response from AI" 
        });
      }

      return res.status(200).json({ 
        success: true, 
        response: aiResponse 
      });

    } catch (error) {
      console.error("Function error:", error);
      return res.status(500).json({ 
        success: false, 
        error: "Internal server error. Please try again." 
      });
    }
  });
});

/**
 * Health check endpoint
 */
exports.health = functions.https.onRequest((req, res) => {
  corsHandler(req, res, () => {
    res.status(200).json({ 
      status: "healthy", 
      timestamp: new Date().toISOString(),
      service: "EduVerse AI Backend"
    });
  });
});
