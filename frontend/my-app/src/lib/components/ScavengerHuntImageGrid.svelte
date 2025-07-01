<script lang="ts">
	interface Props {
		projectId: string;
		slots?: Array<{ id: number; image?: string; filename?: string }>;
		onSlotsUpdate?: (slots: Array<{ id: number; image?: string; filename?: string }>) => void;
	}

	let { projectId, slots = [], onSlotsUpdate }: Props = $props();
	
	// Function to delete slideshow.mp4 when images are moved
	async function deleteSlideshow() {
		try {
			await fetch(`http://localhost:3000/api/uploads/${projectId}/files/slideshow.mp4`, {
				method: 'DELETE'
			});
		} catch (error) {
			// Silently ignore errors - slideshow.mp4 might not exist
			console.log('Slideshow file not found or already deleted');
		}
	}
	
	// Initialize 12 empty slots if not provided
	let imageSlots = $state(
		slots.length === 12 ? slots : 
		Array.from({ length: 12 }, (_, i) => ({ 
			id: i + 1, 
			image: slots[i]?.image, 
			filename: slots[i]?.filename 
		}))
	);
	
	let uploadingSlots = $state<Set<number>>(new Set());
	let dragOverSlot = $state<number | null>(null);

	// Get all currently uploaded filenames for duplicate detection
	function getUploadedFilenames(): Set<string> {
		return new Set(
			imageSlots
				.filter(slot => slot.filename)
				.map(slot => slot.filename!)
		);
	}

	async function handleSlotUpload(slotId: number, file: File) {
		const uploadedFilenames = getUploadedFilenames();
		
		// Check for duplicate filename
		if (uploadedFilenames.has(file.name)) {
			alert(`Image "${file.name}" is already uploaded in another slot. Please choose a different image.`);
			return;
		}

		uploadingSlots.add(slotId);
		uploadingSlots = uploadingSlots; // Trigger reactivity

		try {
			const formData = new FormData();
			formData.append('images', file);
			formData.append('slot', slotId.toString());

			const response = await fetch(`http://localhost:3000/api/uploads/${projectId}/scavenger-hunt-slot`, {
				method: 'POST',
				body: formData
			});

			if (response.ok) {
				const result = await response.json();
				const slotIndex = slotId - 1;
				imageSlots[slotIndex] = {
					id: slotId,
					image: `/api/uploads/${projectId}/images/${result.filename}`,
					filename: result.filename
				};
				
				// Delete slideshow.mp4 since images have changed
				await deleteSlideshow();
				
				onSlotsUpdate?.(imageSlots);
			} else {
				const error = await response.json();
				alert(`Upload failed: ${error.error || 'Unknown error'}`);
			}
		} catch (error) {
			console.error('Upload error:', error);
			alert('Upload failed. Please try again.');
		} finally {
			uploadingSlots.delete(slotId);
			uploadingSlots = uploadingSlots; // Trigger reactivity
		}
	}

	async function removeSlotImage(slotId: number) {
		const slot = imageSlots[slotId - 1];
		if (!slot.filename) return;

		try {
			const response = await fetch(`http://localhost:3000/api/uploads/${projectId}/files/${slot.filename}`, {
				method: 'DELETE'
			});

			if (response.ok) {
				const slotIndex = slotId - 1;
				imageSlots[slotIndex] = { id: slotId };
				
				// Delete slideshow.mp4 since images have changed
				await deleteSlideshow();
				
				onSlotsUpdate?.(imageSlots);
			} else {
				alert('Failed to remove image. Please try again.');
			}
		} catch (error) {
			console.error('Remove error:', error);
			alert('Failed to remove image. Please try again.');
		}
	}

	function handleFileSelect(slotId: number, event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (file) {
			handleSlotUpload(slotId, file);
		}
		// Reset input to allow re-uploading same file
		input.value = '';
	}

	function handleDrop(slotId: number, event: DragEvent) {
		event.preventDefault();
		dragOverSlot = null;
		
		const files = event.dataTransfer?.files;
		if (files && files.length > 0) {
			const file = files[0];
			// Validate file type
			if (file.type.startsWith('image/')) {
				handleSlotUpload(slotId, file);
			} else {
				alert('Please upload an image file (JPEG, PNG, HEIC, etc.)');
			}
		}
	}

	function handleDragOver(slotId: number, event: DragEvent) {
		event.preventDefault();
		dragOverSlot = slotId;
	}

	function handleDragLeave(event: DragEvent) {
		event.preventDefault();
		dragOverSlot = null;
	}
</script>

<div class="scavenger-hunt-grid">
	<div class="grid grid-cols-4 gap-4 max-w-4xl mx-auto">
		{#each imageSlots as slot (slot.id)}
			<div 
				class="slot aspect-square border-2 border-dashed border-gray-300 rounded-lg relative overflow-hidden transition-all duration-200 hover:border-gray-400 {dragOverSlot === slot.id ? 'border-blue-500 bg-blue-50' : ''}"
				ondrop={(e) => handleDrop(slot.id, e)}
				ondragover={(e) => handleDragOver(slot.id, e)}
				ondragleave={handleDragLeave}
			>
				<!-- Slot Number Badge -->
				<div class="absolute top-2 left-2 z-10 bg-black bg-opacity-60 text-white text-xs px-2 py-1 rounded">
					{slot.id}
				</div>

				{#if slot.image}
					<!-- Image Display -->
					<img 
						src={`http://localhost:3000${slot.image}`} 
						alt="Slot {slot.id}" 
						class="w-full h-full object-cover"
					/>
					
					<!-- Remove Button -->
					<button
						onclick={() => removeSlotImage(slot.id)}
						class="absolute top-2 right-2 z-10 bg-red-500 hover:bg-red-600 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs transition-colors"
						title="Remove image"
					>
						×
					</button>
					
					<!-- Replace Button -->
					<label class="absolute inset-0 bg-black bg-opacity-0 hover:bg-opacity-20 transition-all cursor-pointer flex items-center justify-center">
						<input
							type="file"
							accept="image/*"
							onchange={(e) => handleFileSelect(slot.id, e)}
							class="hidden"
						/>
						<div class="opacity-0 hover:opacity-100 transition-opacity bg-white bg-opacity-90 rounded px-3 py-1 text-sm">
							Replace
						</div>
					</label>
				{:else if uploadingSlots.has(slot.id)}
					<!-- Uploading State -->
					<div class="flex flex-col items-center justify-center h-full text-gray-500">
						<svg class="animate-spin h-8 w-8 mb-2" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						<span class="text-sm">Uploading...</span>
					</div>
				{:else}
					<!-- Empty Slot -->
					<label class="flex flex-col items-center justify-center h-full cursor-pointer text-gray-400 hover:text-gray-600 transition-colors">
						<input
							type="file"
							accept="image/*"
							onchange={(e) => handleFileSelect(slot.id, e)}
							class="hidden"
						/>
						<svg class="w-12 h-12 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
						</svg>
						<span class="text-sm text-center px-2">
							Add Image<br>
							<span class="text-xs">or drag & drop</span>
						</span>
					</label>
				{/if}
			</div>
		{/each}
	</div>

	<!-- Progress Indicator -->
	<div class="mt-6 text-center">
		<div class="text-sm text-gray-600 mb-2">
			{imageSlots.filter(slot => slot.image).length} of 12 slots filled
		</div>
		<div class="w-full max-w-md mx-auto bg-gray-200 rounded-full h-2">
			<div 
				class="bg-green-500 h-2 rounded-full transition-all duration-300"
				style="width: {(imageSlots.filter(slot => slot.image).length / 12) * 100}%"
			></div>
		</div>
	</div>
</div>

<style>
	.slot {
		min-height: 150px;
	}
	
	@media (max-width: 768px) {
		.grid {
			grid-template-columns: repeat(3, 1fr);
		}
	}
	
	@media (max-width: 480px) {
		.grid {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>