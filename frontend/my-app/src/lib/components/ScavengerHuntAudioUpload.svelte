<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import ScavengerHuntAudioPlayer from './ScavengerHuntAudioPlayer.svelte';
	
	interface Props {
		projectId: string;
		hasAudio: boolean;
		audioFile?: string;
		audioTrimmed?: boolean;
		audioDuration?: number;
		audioOffset?: string;
	}
	
	let { projectId, hasAudio, audioFile, audioTrimmed = false, audioDuration, audioOffset }: Props = $props();
	const dispatch = createEventDispatcher();
	
	// Debug logging
	$effect(() => {
		console.log('ScavengerHuntAudioUpload props:', { 
			hasAudio, 
			audioFile, 
			audioTrimmed, 
			audioDuration, 
			audioOffset 
		});
	});
	
	let uploading = $state(false);
	let youtubeUrl = $state('');
	let startTime = $state('0:00');
	
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

{#if hasAudio && audioFile}
	{#if audioTrimmed}
		<!-- Show mini player for processed audio -->
		<ScavengerHuntAudioPlayer 
			{projectId} 
			{audioFile} 
			{audioDuration}
			{audioOffset}
			on:uploaded={() => dispatch('uploaded')}
		/>
	{:else}
		<!-- Show basic audio info for unprocessed audio -->
		<div class="bg-white rounded-lg border border-gray-200 p-6">
			<div class="flex items-center justify-between">
				<div class="flex items-center space-x-4">
					<svg class="h-10 w-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
			
			<!-- Basic Audio Player -->
			<audio controls class="w-full mt-4">
				<source src="http://localhost:3000/api/files/{projectId}/{audioFile}" />
			</audio>
		</div>
	{/if}
{:else}
	<!-- YouTube URL Upload Form -->
	<div class="bg-white rounded-lg border border-gray-200 p-6">
		<!-- YouTube URL Only -->
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
					class="block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-green-600 sm:text-sm sm:leading-6"
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
					class="block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-green-600 sm:text-sm sm:leading-6"
					disabled={uploading}
				/>
				<p class="text-xs text-gray-500 mt-1">
					Specify where to start extracting audio (default: 0:00)
				</p>
			</div>
			
			<button
				onclick={handleYouTubeSubmit}
				disabled={uploading || !youtubeUrl.trim()}
				class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
			>
				{uploading ? 'Processing (yt-dlp + ffmpeg + madmom)...' : 'Download & Process Audio'}
			</button>
			
			{#if uploading}
				<div class="text-sm text-gray-600 bg-gray-50 p-3 rounded-md">
					<p class="font-medium mb-1">Processing steps:</p>
					<ul class="list-disc list-inside space-y-1 text-xs">
						<li>Downloading audio with yt-dlp</li>
						<li>Converting audio to MP3 with ffmpeg</li>
						<li>Trimming to 73 seconds for Scavenger Hunt</li>
					</ul>
					<p class="text-xs text-gray-500 mt-2">Check Docker terminal for detailed logs</p>
				</div>
			{/if}
		</div>
	</div>
{/if}