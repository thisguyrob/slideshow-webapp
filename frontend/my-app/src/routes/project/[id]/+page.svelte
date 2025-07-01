<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import ImageUpload from '$lib/components/ImageUpload.svelte';
	import ImageGallery from '$lib/components/ImageGallery.svelte';
	import AudioUpload from '$lib/components/AudioUpload.svelte';
	import SlideshowViewer from '$lib/components/SlideshowViewer.svelte';
	import ProcessingStatus from '$lib/components/ProcessingStatus.svelte';
	
	let project = $state<any>(null);
	let loading = $state(true);
	let activeTab = $state<'images' | 'slideshow'>('images');
	let showSlideshow = $state(false);
	
	const projectId = $page.params.id;
	
	async function loadProject() {
		try {
			const response = await fetch(`http://localhost:3000/api/projects/${projectId}`);
			if (response.ok) {
				project = await response.json();
			} else {
				goto('/');
			}
		} catch (error) {
			console.error('Failed to load project:', error);
			goto('/');
		} finally {
			loading = false;
		}
	}
	
	onMount(() => {
		loadProject();
		
		// Set up WebSocket for real-time updates
		const ws = new WebSocket('ws://localhost:3000');
		
		ws.onmessage = (event) => {
			const data = JSON.parse(event.data);
			if (data.projectId === projectId) {
				project = { ...project, ...data };
			}
		};
		
		return () => {
			ws.close();
		};
	});
	
	function handleImagesUploaded() {
		loadProject();
	}
	
	function handleAudioUploaded() {
		loadProject();
	}
	
	async function startProcessing(mode: 'normal' | 'emotional' = 'normal') {
		try {
			const response = await fetch(`http://localhost:3000/api/process/${projectId}/process`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ mode })
			});
			
			if (response.ok) {
				project.status = 'processing';
			}
		} catch (error) {
			console.error('Failed to start processing:', error);
		}
	}
</script>

{#if loading}
	<div class="min-h-screen bg-gray-50 flex justify-center items-center">
		<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
	</div>
{:else if project}
	<div class="min-h-screen bg-gray-50">
		<!-- Header -->
		<header class="bg-white shadow-sm border-b">
			<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
				<div class="flex justify-between items-center h-16">
					<div class="flex items-center">
						<a href="/" class="text-gray-500 hover:text-gray-700 mr-4">
							<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
							</svg>
						</a>
						<h1 class="text-2xl font-bold text-gray-900">{project.name}</h1>
					</div>
					
					{#if project.images?.length > 0 && project.audio}
						<div class="flex items-center space-x-3">
							{#if project.status === 'processing'}
								<ProcessingStatus {project} />
							{:else if project.video}
								<a
									href="http://localhost:3000/api/process/{projectId}/download"
									class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
								>
									<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
									</svg>
									Download Video
								</a>
							{:else}
								<button
									onclick={() => startProcessing('normal')}
									class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
								>
									<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
									</svg>
									Generate Slideshow
								</button>
							{/if}
						</div>
					{/if}
				</div>
			</div>
		</header>

		<!-- Tab Navigation -->
		<div class="bg-white border-b">
			<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
				<nav class="-mb-px flex space-x-8" aria-label="Tabs">
					<button
						onclick={() => activeTab = 'images'}
						class="py-4 px-1 border-b-2 font-medium text-sm {activeTab === 'images' ? 'border-indigo-500 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
					>
						Images & Audio
					</button>
					<button
						onclick={() => activeTab = 'slideshow'}
						class="py-4 px-1 border-b-2 font-medium text-sm {activeTab === 'slideshow' ? 'border-indigo-500 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
					>
						Preview Slideshow
					</button>
				</nav>
			</div>
		</div>

		<!-- Main Content -->
		<main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
			{#if activeTab === 'images'}
				<div class="space-y-8">
					<!-- Image Upload Section -->
					<div>
						<h2 class="text-lg font-medium text-gray-900 mb-4">Images</h2>
						{#if !project.images || project.images.length === 0}
							<ImageUpload {projectId} on:uploaded={handleImagesUploaded} />
						{:else}
							<ImageGallery 
								{project} 
								on:updated={loadProject}
								on:add-more={handleImagesUploaded}
							/>
						{/if}
					</div>
					
					<!-- Audio Upload Section -->
					<div>
						<h2 class="text-lg font-medium text-gray-900 mb-4">Audio</h2>
						<AudioUpload 
							{projectId} 
							hasAudio={!!project.audio}
							audioFile={project.audio}
							on:uploaded={handleAudioUploaded}
						/>
					</div>
				</div>
			{:else if activeTab === 'slideshow'}
				{#if project.images?.length > 0}
					<SlideshowViewer {project} />
				{:else}
					<div class="text-center py-12">
						<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
						</svg>
						<h3 class="mt-2 text-sm font-medium text-gray-900">No images uploaded</h3>
						<p class="mt-1 text-sm text-gray-500">Upload some images to preview the slideshow.</p>
					</div>
				{/if}
			{/if}
		</main>
	</div>
{/if}
</script>