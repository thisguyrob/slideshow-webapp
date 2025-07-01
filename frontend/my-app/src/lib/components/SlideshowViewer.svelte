<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	
	interface Props {
		project: any;
	}
	
	let { project }: Props = $props();
	
	let currentIndex = $state(0);
	let isPlaying = $state(false);
	let interval: NodeJS.Timeout;
	let transitionDuration = $state(3000); // 3 seconds per slide
	let imageElement: HTMLImageElement;
	
	$effect(() => {
		// Cleanup on unmount or when playing stops
		return () => {
			if (interval) {
				clearInterval(interval);
			}
		};
	});
	
	function play() {
		isPlaying = true;
		interval = setInterval(() => {
			nextSlide();
		}, transitionDuration);
	}
	
	function pause() {
		isPlaying = false;
		if (interval) {
			clearInterval(interval);
		}
	}
	
	function nextSlide() {
		currentIndex = (currentIndex + 1) % project.images.length;
	}
	
	function previousSlide() {
		currentIndex = currentIndex === 0 ? project.images.length - 1 : currentIndex - 1;
	}
	
	function goToSlide(index: number) {
		currentIndex = index;
		if (isPlaying) {
			pause();
			play();
		}
	}
	
	function handleKeydown(e: KeyboardEvent) {
		switch (e.key) {
			case 'ArrowLeft':
				previousSlide();
				break;
			case 'ArrowRight':
				nextSlide();
				break;
			case ' ':
				e.preventDefault();
				isPlaying ? pause() : play();
				break;
			case 'Escape':
				if (document.fullscreenElement) {
					document.exitFullscreen();
				}
				break;
		}
	}
	
	function toggleFullscreen() {
		if (!document.fullscreenElement) {
			document.documentElement.requestFullscreen();
		} else {
			document.exitFullscreen();
		}
	}
	
	function getImageUrl(filename: string) {
		return `http://localhost:3000/api/files/${project.id}/${filename}`;
	}
	
	onMount(() => {
		document.addEventListener('keydown', handleKeydown);
		return () => {
			document.removeEventListener('keydown', handleKeydown);
		};
	});
</script>

<div class="relative bg-black rounded-lg overflow-hidden">
	<!-- Main Image Display -->
	<div class="relative aspect-video">
		<img
			bind:this={imageElement}
			src={getImageUrl(project.images[currentIndex])}
			alt="Slide {currentIndex + 1}"
			class="w-full h-full object-contain"
		/>
		
		<!-- Navigation Overlay -->
		<div class="absolute inset-0 flex items-center justify-between p-4 opacity-0 hover:opacity-100 transition-opacity">
			<button
				onclick={previousSlide}
				class="p-2 rounded-full bg-black bg-opacity-50 text-white hover:bg-opacity-75 transition-colors"
			>
				<svg class="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
				</svg>
			</button>
			
			<button
				onclick={nextSlide}
				class="p-2 rounded-full bg-black bg-opacity-50 text-white hover:bg-opacity-75 transition-colors"
			>
				<svg class="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
				</svg>
			</button>
		</div>
		
		<!-- Slide Counter -->
		<div class="absolute top-4 right-4 bg-black bg-opacity-50 text-white px-3 py-1 rounded-full text-sm">
			{currentIndex + 1} / {project.images.length}
		</div>
	</div>
	
	<!-- Controls Bar -->
	<div class="bg-gray-900 p-4">
		<div class="flex items-center justify-between mb-4">
			<div class="flex items-center space-x-4">
				<!-- Play/Pause Button -->
				<button
					onclick={() => isPlaying ? pause() : play()}
					class="p-2 rounded-full bg-gray-700 text-white hover:bg-gray-600 transition-colors"
				>
					{#if isPlaying}
						<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6"></path>
						</svg>
					{:else}
						<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
						</svg>
					{/if}
				</button>
				
				<!-- Previous/Next Buttons -->
				<button
					onclick={previousSlide}
					class="p-2 rounded bg-gray-700 text-white hover:bg-gray-600 transition-colors"
				>
					<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0019 16V8a1 1 0 00-1.6-.8l-5.333 4zM4.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0011 16V8a1 1 0 00-1.6-.8l-5.334 4z"></path>
					</svg>
				</button>
				<button
					onclick={nextSlide}
					class="p-2 rounded bg-gray-700 text-white hover:bg-gray-600 transition-colors"
				>
					<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.933 12.8a1 1 0 000-1.6L6.6 7.2A1 1 0 005 8v8a1 1 0 001.6.8l5.333-4zM19.933 12.8a1 1 0 000-1.6l-5.333-4A1 1 0 0013 8v8a1 1 0 001.6.8l5.333-4z"></path>
					</svg>
				</button>
			</div>
			
			<!-- Speed Control -->
			<div class="flex items-center space-x-2 text-white">
				<label for="speed" class="text-sm">Speed:</label>
				<select
					id="speed"
					bind:value={transitionDuration}
					onchange={() => {
						if (isPlaying) {
							pause();
							play();
						}
					}}
					class="bg-gray-700 text-white rounded px-2 py-1 text-sm"
				>
					<option value={2000}>Fast (2s)</option>
					<option value={3000}>Normal (3s)</option>
					<option value={5000}>Slow (5s)</option>
					<option value={10000}>Very Slow (10s)</option>
				</select>
			</div>
			
			<!-- Fullscreen Button -->
			<button
				onclick={toggleFullscreen}
				class="p-2 rounded bg-gray-700 text-white hover:bg-gray-600 transition-colors"
			>
				<svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"></path>
				</svg>
			</button>
		</div>
		
		<!-- Thumbnail Strip -->
		<div class="flex space-x-2 overflow-x-auto pb-2">
			{#each project.images as filename, index}
				<button
					onclick={() => goToSlide(index)}
					class="flex-shrink-0 w-20 h-20 rounded overflow-hidden border-2 transition-colors {index === currentIndex ? 'border-indigo-500' : 'border-transparent'}"
				>
					<img
						src={getImageUrl(filename)}
						alt="Thumbnail {index + 1}"
						class="w-full h-full object-cover"
					/>
				</button>
			{/each}
		</div>
	</div>
</div>

<div class="mt-4 text-sm text-gray-500 text-center">
	Tip: Use arrow keys to navigate, spacebar to play/pause, and ESC to exit fullscreen
</div>
</script>