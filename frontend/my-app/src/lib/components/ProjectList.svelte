<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { getApiUrl } from '$lib/config';
	
	interface Project {
		id: string;
		name: string;
		type: string;
		createdAt: string;
		imageCount: number;
		hasAudio: boolean;
		status?: string;
	}
	
	interface Props {
		projects: Project[];
	}
	
	let { projects }: Props = $props();
	const dispatch = createEventDispatcher();
	
	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			month: 'short',
			day: 'numeric',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
	
	async function deleteProject(projectId: string) {
		if (!confirm('Are you sure you want to delete this project?')) return;
		
		try {
			const response = await fetch(`${getApiUrl()}/api/projects/${projectId}`, {
				method: 'DELETE'
			});
			
			if (response.ok) {
				dispatch('refresh');
			}
		} catch (error) {
			console.error('Failed to delete project:', error);
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
	
	function getProjectRoute(project: Project) {
		switch (project.type) {
			case 'FWI-main': return `/fwi-main/${project.id}`;
			case 'FWI-emotional': return `/fwi-emotional/${project.id}`;
			case 'Scavenger-Hunt': return `/scavenger-hunt/${project.id}`;
			default: return `/project/${project.id}`;
		}
	}
</script>

<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
	{#each projects as project}
		<div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow">
			<a href="{getProjectRoute(project)}" class="block">
				<div class="px-4 py-5 sm:p-6">
					<div class="flex items-center justify-between">
						<div class="flex-1 min-w-0">
							<div class="flex items-center gap-2 mb-1">
								<h3 class="text-lg font-medium text-gray-900 truncate">
									{project.name}
								</h3>
								<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getProjectTypeColor(project.type)}">
									{getProjectTypeLabel(project.type)}
								</span>
							</div>
							<p class="mt-1 text-sm text-gray-500">
								{formatDate(project.createdAt)}
							</p>
						</div>
						{#if project.status === 'processing'}
							<div class="ml-4 flex-shrink-0">
								<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
							</div>
						{/if}
					</div>
					
					<div class="mt-4 flex items-center justify-between">
						<div class="flex items-center space-x-4 text-sm text-gray-500">
							<span class="flex items-center">
								<svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
								</svg>
								{project.imageCount} images
							</span>
							{#if project.hasAudio}
								<span class="flex items-center">
									<svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
									</svg>
									Audio
								</span>
							{/if}
						</div>
					</div>
				</div>
			</a>
			
			<div class="bg-gray-50 px-4 py-3 sm:px-6">
				<div class="flex justify-between items-center">
					<a
						href="{getProjectRoute(project)}"
						class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
					>
						Open Project
					</a>
					<button
						onclick={(e) => {
							e.preventDefault();
							deleteProject(project.id);
						}}
						class="text-sm font-medium text-red-600 hover:text-red-500"
					>
						Delete
					</button>
				</div>
			</div>
		</div>
	{/each}
</div>