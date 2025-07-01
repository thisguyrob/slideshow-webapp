<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	
	interface Props {
		projectId: string;
		hasAudio: boolean;
		audioFile?: string;
	}
	
	let { projectId, hasAudio, audioFile }: Props = $props();
	const dispatch = createEventDispatcher();
	
	let uploading = $state(false);
	let uploadMode = $state<'file' | 'youtube'>('file');
	let youtubeUrl = $state('');
	let startTime = $state('0:00');
	let fileInput: HTMLInputElement;
	
	async function handleFileUpload(e: Event) {
		const target = e.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;
		
		if (!file.type.startsWith('audio/') && !file.name.match(/\.(mp3|wav|m4a|aac)$/i)) {
			alert('Please select an audio file');
			return;
		}
		
		uploading = true;
		const formData = new FormData();
		formData.append('audio', file);
		
		try {
			const response = await fetch(`http://localhost:3000/api/upload/${projectId}/audio`, {
				method: 'POST',
				body: formData
			});
			
			if (response.ok) {
				dispatch('uploaded');
			} else {
				alert('Upload failed. Please try again.');
			}
		} catch (error) {
			console.error('Upload error:', error);
			alert('Upload failed. Please try again.');
		} finally {
			uploading = false;
			fileInput.value = '';
		}
	}
	
	async function handleYouTubeSubmit() {
		if (!youtubeUrl.trim()) {
			alert('Please enter a YouTube URL');
			return;
		}
		
		uploading = true;
		
		try {
			// Save URL first
			const response = await fetch(`http://localhost:3000/api/upload/${projectId}/youtube`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ url: youtubeUrl })
			});
			
			if (response.ok) {
				// Start download and processing pipeline
				const downloadResponse = await fetch(`http://localhost:3000/api/upload/${projectId}/youtube-download`, {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json'
					},
					body: JSON.stringify({ 
						url: youtubeUrl,
						startTime: startTime || '0:00'
					})
				});
				
				if (downloadResponse.ok) {
					dispatch('uploaded');
					youtubeUrl = '';
					startTime = '0:00';
				} else {
					const errorData = await downloadResponse.json();
					alert(`Download failed: ${errorData.error || 'Unknown error'}`);
				}
			} else {
				alert('Invalid YouTube URL. Please try again.');
			}
		} catch (error) {
			console.error('YouTube error:', error);
			alert('Failed to process YouTube URL. Please try again.');
		} finally {
			uploading = false;
		}
	}
	
	async function deleteAudio() {
		if (!confirm('Delete the audio file?')) return;
		
		try {
			const response = await fetch(`http://localhost:3000/api/upload/${projectId}/files/${audioFile}`, {
				method: 'DELETE'
			});
			
			if (response.ok) {
				dispatch('uploaded');
			}
		} catch (error) {
			console.error('Failed to delete audio:', error);
		}
	}
</script>

<div class="bg-white rounded-lg border border-gray-200 p-6">
	{#if hasAudio && audioFile}
		<div class="flex items-center justify-between">
			<div class="flex items-center space-x-4">
				<svg class="h-10 w-10 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
				</svg>
				<div>
					<p class="text-sm font-medium text-gray-900">Audio uploaded</p>
					<p class="text-sm text-gray-500">{audioFile}</p>
				</div>
			</div>
			<button
				onclick={deleteAudio}
				class="text-sm font-medium text-red-600 hover:text-red-500"
			>
				Remove
			</button>
		</div>
		
		<!-- Audio Player -->
		<audio controls class="w-full mt-4">
			<source src="http://localhost:3000/api/files/{projectId}/{audioFile}" />
		</audio>
	{:else}
		<!-- Upload Options -->
		<div class="flex space-x-4 mb-4">
			<button
				onclick={() => uploadMode = 'file'}
				class="flex-1 py-2 px-4 border rounded-md text-sm font-medium {uploadMode === 'file' ? 'border-indigo-500 text-indigo-600 bg-indigo-50' : 'border-gray-300 text-gray-700 bg-white hover:bg-gray-50'}"
			>
				Upload File
			</button>
			<button
				onclick={() => uploadMode = 'youtube'}
				class="flex-1 py-2 px-4 border rounded-md text-sm font-medium {uploadMode === 'youtube' ? 'border-indigo-500 text-indigo-600 bg-indigo-50' : 'border-gray-300 text-gray-700 bg-white hover:bg-gray-50'}"
			>
				YouTube URL
			</button>
		</div>
		
		{#if uploadMode === 'file'}
			<div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-dashed border-gray-300 rounded-lg">
				<div class="space-y-1 text-center">
					<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
					</svg>
					<div class="flex text-sm text-gray-600">
						<label for="audio-upload" class="relative cursor-pointer rounded-md font-medium text-indigo-600 hover:text-indigo-500">
							<span>Upload audio file</span>
							<input
								bind:this={fileInput}
								id="audio-upload"
								type="file"
								class="sr-only"
								accept="audio/*,.mp3,.wav,.m4a,.aac"
								onchange={handleFileUpload}
								disabled={uploading}
							/>
						</label>
					</div>
					<p class="text-xs text-gray-500">
						MP3, WAV, M4A, or AAC
					</p>
				</div>
			</div>
		{:else}
			<div class="space-y-4">
				<div>
					<label for="youtube-url" class="block text-sm font-medium text-gray-700 mb-2">
						YouTube URL
					</label>
					<input
						id="youtube-url"
						type="text"
						bind:value={youtubeUrl}
						placeholder="https://www.youtube.com/watch?v=..."
						class="block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
						disabled={uploading}
					/>
				</div>
				
				<div>
					<label for="start-time" class="block text-sm font-medium text-gray-700 mb-2">
						Start Time (optional)
					</label>
					<input
						id="start-time"
						type="text"
						bind:value={startTime}
						placeholder="0:00 (mm:ss or hh:mm:ss)"
						class="block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
						disabled={uploading}
					/>
					<p class="text-xs text-gray-500 mt-1">
						Specify where to start extracting audio (default: 0:00)
					</p>
				</div>
				
				<button
					onclick={handleYouTubeSubmit}
					disabled={uploading || !youtubeUrl.trim()}
					class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					{uploading ? 'Processing (yt-dlp + ffmpeg + madmom)...' : 'Download & Process Audio'}
				</button>
				
				{#if uploading}
					<div class="text-sm text-gray-600 bg-gray-50 p-3 rounded-md">
						<p class="font-medium mb-1">Processing steps:</p>
						<ul class="list-disc list-inside space-y-1 text-xs">
							<li>Downloading audio with yt-dlp</li>
							<li>Converting audio to MP3 with ffmpeg</li>
							<li>Detecting downbeats with madmom</li>
						</ul>
						<p class="text-xs text-gray-500 mt-2">Check Docker terminal for detailed logs</p>
					</div>
				{/if}
			</div>
		{/if}
	{/if}
</div>
