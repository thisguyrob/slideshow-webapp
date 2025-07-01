<script lang="ts">
	import { onMount } from 'svelte';
	import ProjectList from '$lib/components/ProjectList.svelte';
	import CreateProject from '$lib/components/CreateProject.svelte';
	
	let projects = $state<any[]>([]);
	let loading = $state(true);
	let showCreateModal = $state(false);
	
	async function loadProjects() {
		try {
			const response = await fetch('http://localhost:3000/api/projects');
			if (response.ok) {
				projects = await response.json();
			}
		} catch (error) {
			console.error('Failed to load projects:', error);
		} finally {
			loading = false;
		}
	}
	
	onMount(() => {
		loadProjects();
	});
	
	function handleProjectCreated() {
		showCreateModal = false;
		loadProjects();
	}
</script>

<div class="min-h-screen bg-gray-50">
	<!-- Header -->
	<header class="bg-white shadow-sm border-b">
		<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
			<div class="flex justify-between items-center h-16">
				<div class="flex items-center">
					<h1 class="text-2xl font-bold text-gray-900">Slideshow Creator</h1>
				</div>
				<button
					onclick={() => showCreateModal = true}
					class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
				>
					<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
					</svg>
					New Project
				</button>
			</div>
		</div>
	</header>

	<!-- Main Content -->
	<main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
		{#if loading}
			<div class="flex justify-center items-center h-64">
				<div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
			</div>
		{:else if projects.length === 0}
			<div class="text-center py-12">
				<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m-9 1V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z"></path>
				</svg>
				<h3 class="mt-2 text-sm font-medium text-gray-900">No projects</h3>
				<p class="mt-1 text-sm text-gray-500">Get started by creating a new project.</p>
				<div class="mt-6">
					<button
						onclick={() => showCreateModal = true}
						class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
					>
						<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
						</svg>
						New Project
					</button>
				</div>
			</div>
		{:else}
			<ProjectList {projects} on:refresh={loadProjects} />
		{/if}
	</main>
	
	<!-- Create Project Modal -->
	{#if showCreateModal}
		<CreateProject 
			on:close={() => showCreateModal = false}
			on:created={handleProjectCreated}
		/>
	{/if}
</div>