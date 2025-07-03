<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getApiUrl } from '$lib/config';
	import ScavengerHuntImageGrid from '$lib/components/ScavengerHuntImageGrid.svelte';
	import ScavengerHuntAudioUpload from '$lib/components/ScavengerHuntAudioUpload.svelte';
	import SlideshowViewer from '$lib/components/SlideshowViewer.svelte';
	import ProcessingStatus from '$lib/components/ProcessingStatus.svelte';
	
	let project = $state<any>(null);
	let loading = $state(true);
	let activeTab = $state<'images' | 'slideshow'>('images');
	let showSlideshow = $state(false);
	let isRendering = $state(false);
	let hasVideoBeenRendered = $state(false);
	let slots = $state<Array<{ id: number; image?: string; filename?: string }>>([]);
	
	const projectId = $page.params.id;
	
	function isVideoUpToDate(project: any): boolean {
		// If no video exists, it's not up to date
		if (!project.video) return false;
		
		// If no lastProcessed time, assume video is outdated
		if (!project.lastProcessed) return false;
		
		// If project was updated after last processing, video is outdated
		if (project.updatedAt && project.lastProcessed) {
			const updatedTime = new Date(project.updatedAt).getTime();
			const processedTime = new Date(project.lastProcessed).getTime();
			return processedTime >= updatedTime;
		}
		
		// Default to assuming video is up to date if we have it
		return true;
	}
	
	async function loadSlots() {
		try {
			const response = await fetch(`${getApiUrl()}/api/uploads/${projectId}/scavenger-hunt-slots`);
			if (response.ok) {
				const data = await response.json();
				slots = data.slots;
			}
		} catch (error) {
			console.error('Failed to load slots:', error);
			// Initialize with empty slots if loading fails
			slots = Array.from({ length: 12 }, (_, i) => ({ id: i + 1 }));
		}
	}

	async function loadProject() {
		try {
			const response = await fetch(`${getApiUrl()}/api/projects/${projectId}`);
			if (response.ok) {
				project = await response.json();
				// Check if video exists and is up-to-date
				hasVideoBeenRendered = !!project.video && isVideoUpToDate(project);
				// Redirect if project type doesn't match route
				if (project.type !== 'Scavenger-Hunt') {
					goto(`/project/${projectId}`);
					return;
				}
				// Load slots for scavenger hunt projects
				await loadSlots();
			} else {
				console.error('Project not found:', projectId);
				alert('Project not found. Redirecting to home page.');
				goto('/');
			}
		} catch (error) {
			console.error('Failed to load project:', error);
			alert('Failed to load project. Redirecting to home page.');
			goto('/');
		} finally {
			loading = false;
		}
	}
	
	function getProjectTypeLabel(type: string) {
		switch (type) {
			case 'FWI-main': return 'FWI Main';
			case 'FWI-emotional': return 'FWI Emotional';
			case 'Scavenger-Hunt': return 'Scavenger Hunt';
			default: return 'FWI Main';
		}
	}
	
	function getProjectTypeColor(type: string) {
		switch (type) {
			case 'FWI-main': return 'bg-blue-100 text-blue-800';
			case 'FWI-emotional': return 'bg-purple-100 text-purple-800';
			case 'Scavenger-Hunt': return 'bg-green-100 text-green-800';
			default: return 'bg-blue-100 text-blue-800';
		}
	}

	onMount(() => {
		loadProject();
		
		// Set up WebSocket for real-time updates
		const hostname = window.location.hostname;
		const ws = new WebSocket(`ws://${hostname}:3000`);
		
		ws.onmessage = (event) => {
			const data = JSON.parse(event.data);
			if (data.projectId === projectId) {
				// Preserve the project type when updating from WebSocket
				const currentType = project.type;
				project = { ...project, ...data, type: currentType };
				
				// Handle rendering completion
				if (data.type === 'progress' && data.progress === 100) {
					isRendering = false;
					hasVideoBeenRendered = true;
					// Reload project to get updated video info
					loadProject();
				}
				
				// Handle rendering failure
				if (data.type === 'progress' && data.progress === -1) {
					isRendering = false;
				}
			}
		};
		
		return () => {
			ws.close();
		};
	});
	
	function handleImagesUploaded() {
		hasVideoBeenRendered = false;  // Reset video state on image changes
		loadProject();
	}
	
	function handleProjectUpdated() {
		hasVideoBeenRendered = false;  // Reset video state on any project changes (reordering, etc.)
		loadProject();
	}
	
	function handleAudioUploaded() {
		hasVideoBeenRendered = false;  // Reset video state on audio changes
		loadProject();
	}
	
	async function startProcessing(mode: 'normal' | 'emotional' = 'normal') {
		try {
			const response = await fetch(`${getApiUrl()}/api/process/${projectId}/process`, {
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

	async function renderSlideshow() {
		isRendering = true;
		try {
			const response = await fetch(`${getApiUrl()}/api/process/${projectId}/process`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ mode: 'normal' })
			});
			
			if (response.ok) {
				// Processing started successfully
				// The WebSocket will handle status updates
			} else {
				throw new Error('Failed to start rendering');
			}
		} catch (error) {
			console.error('Failed to render slideshow:', error);
			alert('Failed to start rendering. Please try again.');
			isRendering = false;
		}
	}

	function downloadVideo() {
		window.open(`${getApiUrl()}/api/process/${projectId}/download`, '_blank');
	}

	function handleSlotsUpdate(updatedSlots) {
		slots = updatedSlots;
		// Reload project to get updated metadata
		loadProject();
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
						<a href="/" class="text-gray-500 hover:text-gray-700 mr-4" aria-label="Back to home">
							<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path>
							</svg>
						</a>
						<div class="flex items-center gap-3">
							<h1 class="text-2xl font-bold text-gray-900">{project.name}</h1>
							<span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium {getProjectTypeColor(project.type)}">
								{getProjectTypeLabel(project.type)}
							</span>
						</div>
					</div>
					
                                       {#if slots.some(slot => slot.image) && project.audioTrimmed}
						<div class="flex items-center">
							{#if isRendering}
								<button
									disabled
									class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 cursor-not-allowed opacity-75"
								>
									<svg class="animate-spin h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" class="opacity-25"></circle>
										<path fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" class="opacity-75"></path>
									</svg>
									Rendering...
								</button>
							{:else if isVideoUpToDate(project)}
								<button
									onclick={downloadVideo}
									class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
								>
									<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
									</svg>
									Download
								</button>
							{:else if slots.filter(slot => slot.image).length === 12}
								<button
									onclick={renderSlideshow}
									class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700"
								>
									<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
									</svg>
{project.video ? 'Re-render Slideshow' : 'Render Slideshow'}
								</button>
							{:else}
								<button
									disabled
									class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-gray-400 cursor-not-allowed opacity-75"
									title="All 12 image slots must be filled to render slideshow"
								>
									<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
									</svg>
									{slots.filter(slot => slot.image).length}/12 Images Required
								</button>
							{/if}
						</div>
					{/if}
				</div>
			</div>
		</header>


                <!-- Main Content -->
                <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                        {#if activeTab === 'images'}
                                <div class="space-y-8">
                                        {#if !project.audioTrimmed}
                                                <!-- Audio Upload Section (shown first when no audio) -->
                                                <div>
                                                        <h2 class="text-lg font-medium text-gray-900 mb-4">Audio</h2>
                                                        <ScavengerHuntAudioUpload
                                                                {projectId}
                                                                hasAudio={!!project.audio}
                                                                audioFile={project.audio}
                                                                audioTrimmed={project.audioTrimmed}
                                                                audioDuration={project.audioDuration}
                                                                audioOffset={project.audioOffset}
                                                                on:uploaded={handleAudioUploaded}
                                                        />
                                                </div>
                                                <div class="text-sm text-gray-500">
                                                        Please process your audio first. The image slots will appear once the audio is ready.
                                                </div>
                                        {:else}
                                                <!-- Image Grid Section (shown first when audio is set) -->
                                                <div>
                                                        <h2 class="text-lg font-medium text-gray-900 mb-4">Images (12 Slots)</h2>
                                                        <p class="text-sm text-gray-600 mb-6">Upload images to specific slots. Each slot can contain one unique image.</p>
                                                        <ScavengerHuntImageGrid
                                                                {projectId}
                                                                {slots}
                                                                onSlotsUpdate={handleSlotsUpdate}
                                                        />
                                                </div>
                                                
                                                <!-- Audio Upload Section (shown below images when audio is set) -->
                                                <div>
                                                        <h2 class="text-lg font-medium text-gray-900 mb-4">Audio</h2>
                                                        <ScavengerHuntAudioUpload
                                                                {projectId}
                                                                hasAudio={!!project.audio}
                                                                audioFile={project.audio}
                                                                audioTrimmed={project.audioTrimmed}
                                                                audioDuration={project.audioDuration}
                                                                audioOffset={project.audioOffset}
                                                                on:uploaded={handleAudioUploaded}
                                                        />
                                                </div>
                                        {/if}
                                </div>
                        {:else if activeTab === 'slideshow'}
                                {#if slots.some(slot => slot.image) && project.audioTrimmed}
                                        <SlideshowViewer {project} />
                                {:else}
                                        <div class="text-center py-12">
                                                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                                                </svg>
                                                <h3 class="mt-2 text-sm font-medium text-gray-900">Add images and audio first</h3>
                                                <p class="mt-1 text-sm text-gray-500">Upload audio and images to preview the slideshow.</p>
                                        </div>
                                {/if}
                        {/if}
                </main>
	</div>
{/if}