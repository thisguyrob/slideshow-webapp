<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { getApiUrl } from '$lib/config';

	interface Props {
		projectId: string;
		audioFile: string;
		audioDuration?: number;
		audioOffset?: string;
	}

	let { projectId, audioFile, audioDuration = 73, audioOffset }: Props = $props();
	const dispatch = createEventDispatcher();

	let audioElement: HTMLAudioElement;
	let isPlaying = $state(false);
	let currentTime = $state(0);
	let duration = $state(audioDuration);
	let volume = $state(1);

	function togglePlay() {
		if (audioElement) {
			if (isPlaying) {
				audioElement.pause();
			} else {
				audioElement.play();
			}
		}
	}

	function handleTimeUpdate() {
		if (audioElement) {
			currentTime = audioElement.currentTime;
		}
	}

	function handleLoadedMetadata() {
		if (audioElement) {
			duration = audioElement.duration;
		}
	}

	function handleEnded() {
		isPlaying = false;
		currentTime = 0;
	}

	function handlePlay() {
		isPlaying = true;
	}

	function handlePause() {
		isPlaying = false;
	}

	function seek(event: Event) {
		const target = event.target as HTMLInputElement;
		const seekTime = (parseFloat(target.value) / 100) * duration;
		if (audioElement) {
			audioElement.currentTime = seekTime;
		}
	}

	function handleVolumeChange(event: Event) {
		const target = event.target as HTMLInputElement;
		volume = parseFloat(target.value) / 100;
		if (audioElement) {
			audioElement.volume = volume;
		}
	}

	function formatTime(seconds: number): string {
		const mins = Math.floor(seconds / 60);
		const secs = Math.floor(seconds % 60);
		return `${mins}:${secs.toString().padStart(2, '0')}`;
	}

	function getProgressBarStyle(currentTime: number, duration: number): string {
		const progress = duration > 0 ? (currentTime / duration) * 100 : 0;
		
		// Visual indicators for fade zones
		const fadeInEnd = (1 / duration) * 100; // 1 second fade in
		const fadeOutStart = ((duration - 1) / duration) * 100; // 1 second fade out
		
		let gradient = `linear-gradient(to right, `;
		
		// Fade in zone (0-1s)
		gradient += `rgba(34, 197, 94, 0.3) 0%, `;
		gradient += `rgba(34, 197, 94, 0.3) ${fadeInEnd}%, `;
		
		// Main content zone
		gradient += `rgba(34, 197, 94, 0.1) ${fadeInEnd}%, `;
		gradient += `rgba(34, 197, 94, 0.1) ${fadeOutStart}%, `;
		
		// Fade out zone (72-73s)
		gradient += `rgba(34, 197, 94, 0.3) ${fadeOutStart}%, `;
		gradient += `rgba(34, 197, 94, 0.3) 100%)`;
		
		return gradient;
	}

	function replaceAudio() {
		dispatch('replace');
	}
</script>

<div class="bg-white rounded-lg border border-gray-200 p-6">
	<div class="flex items-center justify-between mb-4">
		<div class="flex items-center space-x-4">
			<svg class="h-10 w-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
			</svg>
			<div>
				<p class="text-sm font-medium text-gray-900">Scavenger Hunt Audio Ready</p>
				<p class="text-sm text-gray-500">
					{#if audioOffset && audioOffset !== '0:00'}
						Trimmed from {audioOffset} • {duration}s duration
					{:else}
						{duration}s duration • Trimmed for slideshow
					{/if}
				</p>
			</div>
		</div>
		<button
			onclick={replaceAudio}
			class="text-sm font-medium text-blue-600 hover:text-blue-500"
		>
			Replace
		</button>
	</div>

	<!-- Audio Element -->
	<audio
		bind:this={audioElement}
		ontimeupdate={handleTimeUpdate}
		onloadedmetadata={handleLoadedMetadata}
		onended={handleEnded}
		onplay={handlePlay}
		onpause={handlePause}
		preload="metadata"
	>
		<source src="{getApiUrl()}/api/files/{projectId}/{audioFile}" type="audio/mpeg">
	</audio>

	<!-- Mini Player Controls -->
	<div class="space-y-3">
		<!-- Play/Pause and Time Display -->
		<div class="flex items-center space-x-4">
			<button
				onclick={togglePlay}
				class="flex-shrink-0 w-10 h-10 rounded-full bg-green-600 hover:bg-green-700 text-white flex items-center justify-center transition-colors"
			>
				{#if isPlaying}
					<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
						<path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
					</svg>
				{:else}
					<svg class="w-4 h-4 ml-0.5" fill="currentColor" viewBox="0 0 24 24">
						<path d="M8 5v14l11-7z"/>
					</svg>
				{/if}
			</button>
			
			<div class="text-sm text-gray-500 tabular-nums">
				{formatTime(currentTime)} / {formatTime(duration)}
			</div>
		</div>

		<!-- Progress Bar with Fade Zones -->
		<div class="space-y-2">
			<div class="relative">
				<div 
					class="h-2 rounded-full"
					style="background: {getProgressBarStyle(currentTime, duration)}"
				></div>
				<div 
					class="absolute top-0 left-0 h-2 bg-green-600 rounded-full transition-all duration-100"
					style="width: {duration > 0 ? (currentTime / duration) * 100 : 0}%"
				></div>
				<input
					type="range"
					min="0"
					max="100"
					value={duration > 0 ? (currentTime / duration) * 100 : 0}
					oninput={seek}
					class="absolute top-0 left-0 w-full h-2 opacity-0 cursor-pointer"
				/>
			</div>
			
			<!-- Fade Zone Labels -->
			<div class="flex justify-between text-xs text-gray-400">
				<span>Fade In</span>
				<span>Slideshow Content</span>
				<span>Fade Out</span>
			</div>
		</div>
	</div>
</div>

<style>
	.slider::-webkit-slider-thumb {
		appearance: none;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		background: #059669;
		cursor: pointer;
	}
	
	.slider::-moz-range-thumb {
		width: 16px;
		height: 16px;
		border-radius: 50%;
		background: #059669;
		cursor: pointer;
		border: none;
	}
</style>