#!/usr/bin/env node
/**
 * YouTube URL Add Music Test Script
 * =================================
 * Tests the add music via URL functionality using a specific YouTube URL.
 * This script creates a test project and tests the YouTube URL processing pipeline.
 * 
 * Usage:
 *   node test_youtube_url.js
 */

// Use built-in fetch (Node.js 18+) or polyfill
const fetch = globalThis.fetch;
import path from 'path';
import { promises as fs } from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECTS_DIR = path.join(__dirname, '../projects');
const TEST_URL = 'https://www.youtube.com/watch?v=Z7-QdoofMq8';
const BASE_URL = 'http://localhost:3000/api';

// Test configuration
const TEST_CONFIG = {
  projectName: 'youtube-test-project',
  youtubeUrl: TEST_URL,
  startTime: '0:00',
  timeout: 120000 // 2 minutes timeout
};

class YouTubeUrlTester {
  constructor() {
    this.projectId = null;
    this.testResults = {
      projectCreation: false,
      urlSave: false,
      urlDownload: false,
      audioProcessing: false,
      madmomProcessing: false,
      cleanup: false
    };
  }

  log(message, type = 'info') {
    const timestamp = new Date().toISOString();
    const prefix = {
      info: '📋',
      success: '✅',
      error: '❌',
      warning: '⚠️'
    }[type] || '📋';
    
    console.log(`[${timestamp}] ${prefix} ${message}`);
  }

  async createTestProject() {
    this.log('Creating test project...');
    
    try {
      const response = await fetch(`${BASE_URL}/projects`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name: TEST_CONFIG.projectName,
          description: 'Test project for YouTube URL functionality'
        })
      });

      if (!response.ok) {
        throw new Error(`Failed to create project: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      this.projectId = result.id;
      this.testResults.projectCreation = true;
      this.log(`Project created successfully: ${this.projectId}`, 'success');
      
      return result;
    } catch (error) {
      this.log(`Failed to create project: ${error.message}`, 'error');
      throw error;
    }
  }

  async testYouTubeUrlSave() {
    this.log('Testing YouTube URL save...');
    
    try {
      const response = await fetch(`${BASE_URL}/upload/${this.projectId}/youtube`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          url: TEST_CONFIG.youtubeUrl
        })
      });

      if (!response.ok) {
        throw new Error(`Failed to save YouTube URL: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      this.testResults.urlSave = true;
      this.log(`YouTube URL saved successfully: ${result.url}`, 'success');
      
      // Verify audio.txt was created
      const audioTxtPath = path.join(PROJECTS_DIR, this.projectId, 'audio.txt');
      const savedUrl = await fs.readFile(audioTxtPath, 'utf-8');
      
      if (savedUrl.trim() === TEST_CONFIG.youtubeUrl) {
        this.log('audio.txt verification passed', 'success');
      } else {
        throw new Error('audio.txt content does not match saved URL');
      }
      
      return result;
    } catch (error) {
      this.log(`Failed to save YouTube URL: ${error.message}`, 'error');
      throw error;
    }
  }

  async testYouTubeDownload() {
    this.log('Testing YouTube download and processing...');
    
    try {
      const response = await fetch(`${BASE_URL}/upload/${this.projectId}/youtube-download`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          url: TEST_CONFIG.youtubeUrl,
          startTime: TEST_CONFIG.startTime
        })
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Download failed: ${response.status} ${response.statusText} - ${errorText}`);
      }

      const result = await response.json();
      this.testResults.urlDownload = true;
      this.log(`Download initiated successfully`, 'success');
      
      // Check if audio processing was successful
      if (result.message && result.message.includes('processed successfully')) {
        this.testResults.audioProcessing = true;
        this.log('Audio processing completed', 'success');
      }
      
      // Check if madmom processing was successful
      if (result.downbeatsDetected === true) {
        this.testResults.madmomProcessing = true;
        this.log('Madmom downbeat detection completed', 'success');
      } else if (result.downbeatsDetected === false) {
        this.log('Madmom downbeat detection failed', 'warning');
      }
      
      // Verify song.mp3 was created
      const songPath = path.join(PROJECTS_DIR, this.projectId, 'song.mp3');
      try {
        await fs.access(songPath);
        this.log('song.mp3 file verification passed', 'success');
      } catch (err) {
        this.log('song.mp3 file not found', 'warning');
      }
      
      return result;
    } catch (error) {
      this.log(`Download test failed: ${error.message}`, 'error');
      throw error;
    }
  }

  async cleanupTestProject() {
    if (!this.projectId) return;
    
    this.log('Cleaning up test project...');
    
    try {
      const response = await fetch(`${BASE_URL}/projects/${this.projectId}`, {
        method: 'DELETE'
      });

      if (response.ok) {
        this.testResults.cleanup = true;
        this.log('Test project cleaned up successfully', 'success');
      } else {
        this.log('Failed to cleanup test project via API, attempting manual cleanup', 'warning');
        
        // Manual cleanup
        const projectDir = path.join(PROJECTS_DIR, this.projectId);
        try {
          await fs.rm(projectDir, { recursive: true, force: true });
          this.testResults.cleanup = true;
          this.log('Manual cleanup successful', 'success');
        } catch (err) {
          this.log(`Manual cleanup failed: ${err.message}`, 'error');
        }
      }
    } catch (error) {
      this.log(`Cleanup failed: ${error.message}`, 'error');
    }
  }

  printTestResults() {
    this.log('\n=== TEST RESULTS ===');
    
    const results = [
      ['Project Creation', this.testResults.projectCreation],
      ['YouTube URL Save', this.testResults.urlSave],
      ['YouTube Download', this.testResults.urlDownload],
      ['Audio Processing', this.testResults.audioProcessing],
      ['Madmom Processing', this.testResults.madmomProcessing],
      ['Cleanup', this.testResults.cleanup]
    ];

    results.forEach(([test, passed]) => {
      const status = passed ? '✅ PASS' : '❌ FAIL';
      console.log(`${test}: ${status}`);
    });

    const totalTests = results.length;
    const passedTests = results.filter(([_, passed]) => passed).length;
    
    console.log(`\nOverall: ${passedTests}/${totalTests} tests passed`);
    
    if (passedTests === totalTests) {
      this.log('All tests passed! YouTube URL functionality is working correctly.', 'success');
    } else {
      this.log('Some tests failed. Check the logs above for details.', 'error');
    }
  }

  async runTests() {
    this.log(`Starting YouTube URL tests with: ${TEST_CONFIG.youtubeUrl}`);
    
    try {
      // Test 1: Create project
      await this.createTestProject();
      
      // Test 2: Save YouTube URL
      await this.testYouTubeUrlSave();
      
      // Test 3: Download and process YouTube audio
      await this.testYouTubeDownload();
      
    } catch (error) {
      this.log(`Test execution failed: ${error.message}`, 'error');
    } finally {
      // Always try to cleanup
      await this.cleanupTestProject();
      
      // Print results
      this.printTestResults();
    }
  }
}

// Check if server is running
async function checkServer() {
  try {
    const response = await fetch(`${BASE_URL}/projects`);
    if (!response.ok) {
      throw new Error('Server not responding correctly');
    }
    return true;
  } catch (error) {
    console.log('❌ Server is not running or not accessible at http://localhost:3000');
    console.log('Please start the server first: npm start or node server.js');
    process.exit(1);
  }
}

// Main execution
async function main() {
  console.log('🧪 YouTube URL Add Music Test Script');
  console.log('=====================================');
  
  // Check server availability
  await checkServer();
  
  // Run tests
  const tester = new YouTubeUrlTester();
  await tester.runTests();
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('\n⚠️  Test interrupted. Cleaning up...');
  process.exit(0);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled rejection:', error);
  process.exit(1);
});

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}

export default YouTubeUrlTester;