<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	
	const dispatch = createEventDispatcher();
	
	let projectName = $state('');
	let creating = $state(false);
	let error = $state('');
	
	async function createProject() {
		if (!projectName.trim()) {
			error = 'Please enter a project name';
			return;
		}
		
		creating = true;
		error = '';
		
		try {
			const response = await fetch('http://localhost:3000/api/projects', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ name: projectName })
			});
			
			if (response.ok) {
				const project = await response.json();
				dispatch('created', project);
			} else {
				error = 'Failed to create project';
			}
		} catch (err) {
			error = 'Network error. Please try again.';
		} finally {
			creating = false;
		}
	}
	
	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			dispatch('close');
		} else if (e.key === 'Enter' && !creating) {
			createProject();
		}
	}
</script>

<div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
	<div class="fixed inset-0 overflow-y-auto">
		<div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
			<div
				class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg"
				onkeydown={handleKeydown}
			>
				<div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
					<div class="sm:flex sm:items-start">
						<div class="mx-auto flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-indigo-100 sm:mx-0 sm:h-10 sm:w-10">
							<svg class="h-6 w-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
							</svg>
						</div>
						<div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left flex-1">
							<h3 class="text-base font-semibold leading-6 text-gray-900">
								Create New Project
							</h3>
							<div class="mt-4">
								<input
									type="text"
									bind:value={projectName}
									placeholder="Enter project name"
									class="block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
									autofocus
								/>
								{#if error}
									<p class="mt-2 text-sm text-red-600">{error}</p>
								{/if}
							</div>
						</div>
					</div>
				</div>
				<div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
					<button
						type="button"
						onclick={createProject}
						disabled={creating}
						class="inline-flex w-full justify-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 sm:ml-3 sm:w-auto disabled:opacity-50 disabled:cursor-not-allowed"
					>
						{creating ? 'Creating...' : 'Create'}
					</button>
					<button
						type="button"
						onclick={() => dispatch('close')}
						class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
					>
						Cancel
					</button>
				</div>
			</div>
		</div>
	</div>
</div>
</script>