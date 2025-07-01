<script lang="ts">
	interface Props {
		project: any;
	}
	
	let { project }: Props = $props();
	
	function getProgressPercentage() {
		if (!project.progress) return 0;
		// Assuming progress is reported as a decimal between 0 and 1
		return Math.round(project.progress * 100);
	}
	
	async function cancelProcessing() {
		try {
			const response = await fetch(`http://localhost:3000/api/process/${project.id}/cancel`, {
				method: 'POST'
			});
			
			if (response.ok) {
				project.status = 'cancelled';
			}
		} catch (error) {
			console.error('Failed to cancel processing:', error);
		}
	}
</script>

<div class="flex items-center space-x-4">
	<div class="flex-1">
		<div class="flex items-center space-x-2">
			<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-indigo-600"></div>
			<span class="text-sm text-gray-600">Processing slideshow...</span>
		</div>
		{#if project.progress}
			<div class="mt-2">
				<div class="bg-gray-200 rounded-full h-2 w-32">
					<div 
						class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
						style="width: {getProgressPercentage()}%"
					></div>
				</div>
				<p class="text-xs text-gray-500 mt-1">{getProgressPercentage()}% complete</p>
			</div>
		{/if}
	</div>
	<button
		onclick={cancelProcessing}
		class="px-3 py-1 border border-red-300 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
	>
		Cancel
	</button>
</div>
</script>