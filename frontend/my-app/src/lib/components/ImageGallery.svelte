<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { flip } from 'svelte/animate';
	import { quintOut } from 'svelte/easing';
	
	interface Props {
		project: any;
	}
	
	let { project }: Props = $props();
	const dispatch = createEventDispatcher();
	
	let selectedImages = $state<Set<string>>(new Set());
	let reordering = $state(false);
	let draggedItem = $state<string | null>(null);
	
	function toggleImageSelection(filename: string | {name: string}) {
		const imageName = typeof filename === 'string' ? filename : filename.name;
		if (selectedImages.has(imageName)) {
			selectedImages.delete(imageName);
		} else {
			selectedImages.add(imageName);
		}
		selectedImages = new Set(selectedImages);
	}
	
	async function deleteSelectedImages() {
		if (selectedImages.size === 0) return;
		
		if (!confirm(`Delete ${selectedImages.size} selected images?`)) return;
		
		const promises = Array.from(selectedImages).map(filename =>
			fetch(`http://localhost:3000/api/upload/${project.id}/files/${filename}`, {
				method: 'DELETE'
			})
		);
		
		try {
			await Promise.all(promises);
			selectedImages.clear();
			dispatch('updated');
		} catch (error) {
			console.error('Failed to delete images:', error);
		}
	}
	
	function handleDragStart(e: DragEvent, filename: string | {name: string}) {
		const imageName = typeof filename === 'string' ? filename : filename.name;
		draggedItem = imageName;
		if (e.dataTransfer) {
			e.dataTransfer.effectAllowed = 'move';
		}
	}
	
	function handleDragOver(e: DragEvent) {
		e.preventDefault();
		if (e.dataTransfer) {
			e.dataTransfer.dropEffect = 'move';
		}
	}
	
	function handleDrop(e: DragEvent, targetFilename: string | {name: string}) {
		e.preventDefault();
		const targetName = typeof targetFilename === 'string' ? targetFilename : targetFilename.name;
		if (!draggedItem || draggedItem === targetName) return;
		
		const currentIndex = project.images.findIndex((img: any) => 
			(typeof img === 'string' ? img : img.name) === draggedItem
		);
		const targetIndex = project.images.findIndex((img: any) => 
			(typeof img === 'string' ? img : img.name) === targetName
		);
		
		if (currentIndex !== -1 && targetIndex !== -1) {
			const newImages = [...project.images];
			const item = newImages.splice(currentIndex, 1)[0];
			newImages.splice(targetIndex, 0, item);
			
			saveNewOrder(newImages);
		}
		
		draggedItem = null;
	}
	
	async function saveNewOrder(newImages: any[]) {
		reordering = true;
		
		try {
			// Convert objects to filenames for the API
			const imageFilenames = newImages.map(img => 
				typeof img === 'string' ? img : img.name
			);
			
			const response = await fetch(`http://localhost:3000/api/projects/${project.id}/reorder`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ images: imageFilenames })
			});
			
			if (response.ok) {
				project.images = newImages;
			}
		} catch (error) {
			console.error('Failed to save new order:', error);
		} finally {
			reordering = false;
		}
	}
	
	function getImageUrl(filename: string | {name: string}) {
		const imageName = typeof filename === 'string' ? filename : filename.name;
		return `http://localhost:3000/api/files/${project.id}/${imageName}`;
	}
</script>

<div class="space-y-4">
	<!-- Toolbar -->
	<div class="flex justify-between items-center">
		<div class="flex items-center space-x-4">
			<span class="text-sm text-gray-500">
				{project.images.length} images
			</span>
			{#if selectedImages.size > 0}
				<button
					onclick={deleteSelectedImages}
					class="inline-flex items-center px-3 py-1 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700"
				>
					Delete {selectedImages.size} selected
				</button>
			{/if}
		</div>
		<button
			onclick={() => dispatch('add-more')}
			class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
		>
			<svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
			</svg>
			Add More
		</button>
	</div>
	
	<!-- Image Grid -->
	<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
		{#each project.images as filename (filename)}
			<div
				animate:flip={{ duration: 300, easing: quintOut }}
				draggable="true"
				ondragstart={(e) => handleDragStart(e, filename)}
				ondragover={handleDragOver}
				ondrop={(e) => handleDrop(e, filename)}
				class="relative group cursor-move"
			>
				<div class="aspect-square overflow-hidden rounded-lg bg-gray-100">
					<img
						src={getImageUrl(filename)}
						alt={typeof filename === 'string' ? filename : filename.name}
						class="w-full h-full object-cover group-hover:opacity-75 transition-opacity"
					/>
				</div>
				
				<!-- Selection Checkbox -->
				<div class="absolute top-2 left-2">
					<input
						type="checkbox"
						checked={selectedImages.has(typeof filename === 'string' ? filename : filename.name)}
						onchange={() => toggleImageSelection(filename)}
						class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
					/>
				</div>
				
				<!-- Reorder Indicator -->
				{#if reordering && draggedItem === (typeof filename === 'string' ? filename : filename.name)}
					<div class="absolute inset-0 bg-indigo-600 bg-opacity-20 rounded-lg"></div>
				{/if}
				
				<!-- Image Number -->
				<div class="absolute bottom-2 right-2 bg-black bg-opacity-50 text-white text-xs px-2 py-1 rounded">
					{project.images.findIndex((img: any) => 
						(typeof img === 'string' ? img : img.name) === (typeof filename === 'string' ? filename : filename.name)
					) + 1}
				</div>
			</div>
		{/each}
	</div>
	
	<p class="text-sm text-gray-500 text-center">
		Drag and drop images to reorder them
	</p>
</div>
