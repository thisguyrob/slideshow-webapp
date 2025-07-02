<script lang="ts">
	import { getApiUrl } from '$lib/config';
	
	interface Props {
		projectId: string;
		slots?: Array<{ id: number; image?: string; filename?: string }>;
		onSlotsUpdate?: (slots: Array<{ id: number; image?: string; filename?: string }>) => void;
	}

	let { projectId, slots = [], onSlotsUpdate }: Props = $props();
	
	// Function to delete slideshow.mp4 when images are moved
	async function deleteSlideshow() {
		try {
			await fetch(`${getApiUrl()}/api/uploads/${projectId}/files/slideshow.mp4`, {
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
	let draggedSlot = $state<number | null>(null);
	let isDraggingImage = $state(false);
	let batchUploading = $state(false);
	let batchUploadProgress = $state({ current: 0, total: 0 });

	// Get all currently uploaded filenames for duplicate detection
	function getUploadedFilenames(): Set<string> {
		return new Set(
			imageSlots
				.filter(slot => slot.filename)
				.map(slot => slot.filename!)
		);
	}

	async function handleBatchUpload(files: FileList) {
		const uploadedFilenames = getUploadedFilenames();
		const filesToUpload: Array<{file: File, slotId: number}> = [];
		
		// Find empty slots and prepare upload list
		let slotIndex = 0;
		for (let i = 0; i < files.length && filesToUpload.length < 12; i++) {
			const file = files[i];
			
			// Skip duplicate filenames
			if (uploadedFilenames.has(file.name)) {
				console.log(`Skipping duplicate file: ${file.name}`);
				continue;
			}
			
			// Find next empty slot
			while (slotIndex < 12 && imageSlots[slotIndex].image) {
				slotIndex++;
			}
			
			if (slotIndex < 12) {
				filesToUpload.push({ file, slotId: slotIndex + 1 });
				uploadedFilenames.add(file.name); // Track to prevent duplicates within batch
				slotIndex++;
			}
		}
		
		if (filesToUpload.length === 0) {
			alert('No available slots or all selected images are already uploaded.');
			return;
		}
		
		// Start batch upload
		batchUploading = true;
		batchUploadProgress = { current: 0, total: filesToUpload.length };
		
		// Upload files sequentially to avoid overwhelming the server
		let successCount = 0;
		for (const { file, slotId } of filesToUpload) {
			const success = await handleSlotUpload(slotId, file);
			if (success) {
				successCount++;
			}
			batchUploadProgress.current++;
		}
		
		batchUploading = false;
		
		if (successCount < filesToUpload.length) {
			alert(`Uploaded ${successCount} of ${filesToUpload.length} images. Some uploads may have failed.`);
		}
		
		batchUploadProgress = { current: 0, total: 0 };
	}

	async function handleSlotUpload(slotId: number, file: File): Promise<boolean> {
		const uploadedFilenames = getUploadedFilenames();
		
		// Check for duplicate filename (unless this is from batch upload where we already checked)
		if (!batchUploading && uploadedFilenames.has(file.name)) {
			alert(`Image "${file.name}" is already uploaded in another slot. Please choose a different image.`);
			return false;
		}

		uploadingSlots.add(slotId);
		uploadingSlots = uploadingSlots; // Trigger reactivity

		try {
			const formData = new FormData();
			formData.append('images', file);
			formData.append('slot', slotId.toString());

			const response = await fetch(`${getApiUrl()}/api/uploads/${projectId}/scavenger-hunt-slot`, {
				method: 'POST',
				body: formData
			});

			if (response.ok) {
				const result = await response.json();
				const slotIndex = slotId - 1;
				imageSlots[slotIndex] = {
					id: slotId,
					image: result.file?.url || `/api/files/${projectId}/${result.filename}`,
					filename: result.filename
				};
				
				// Delete slideshow.mp4 since images have changed
				await deleteSlideshow();
				
				onSlotsUpdate?.(imageSlots);
				return true;
			} else {
				const error = await response.json();
				if (!batchUploading) {
					alert(`Upload failed: ${error.error || 'Unknown error'}`);
				}
				return false;
			}
		} catch (error) {
			console.error('Upload error:', error);
			if (!batchUploading) {
				alert('Upload failed. Please try again.');
			}
			return false;
		} finally {
			uploadingSlots.delete(slotId);
			uploadingSlots = uploadingSlots; // Trigger reactivity
		}
	}

	async function removeSlotImage(slotId: number) {
		const slot = imageSlots[slotId - 1];
		if (!slot.filename) return;

		try {
			const response = await fetch(`${getApiUrl()}/api/uploads/${projectId}/files/${slot.filename}`, {
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

	function handleBatchFileSelect(event: Event) {
		const input = event.target as HTMLInputElement;
		const files = input.files;
		if (files && files.length > 0) {
			handleBatchUpload(files);
		}
		// Reset input to allow re-selecting same files
		input.value = '';
	}

	function handleDrop(slotId: number, event: DragEvent) {
		event.preventDefault();
		dragOverSlot = null;
		
		// Check if we're dropping an image from another slot
		if (isDraggingImage && draggedSlot !== null) {
			handleImageReorder(draggedSlot, slotId);
			isDraggingImage = false;
			draggedSlot = null;
			return;
		}
		
		// Otherwise, check for file upload
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
	
	function handleImageDragStart(slotId: number, event: DragEvent) {
		draggedSlot = slotId;
		isDraggingImage = true;
		// Add visual feedback
		const target = event.target as HTMLElement;
		target.style.opacity = '0.5';
		event.dataTransfer!.effectAllowed = 'move';
	}
	
	function handleImageDragEnd(event: DragEvent) {
		// Reset visual feedback
		const target = event.target as HTMLElement;
		target.style.opacity = '1';
		isDraggingImage = false;
		draggedSlot = null;
		dragOverSlot = null;
	}
	
	async function handleImageReorder(fromSlotId: number, toSlotId: number) {
		if (fromSlotId === toSlotId) return;
		
		const fromIndex = fromSlotId - 1;
		const toIndex = toSlotId - 1;
		
		// Get the current slot data
		const fromSlot = { ...imageSlots[fromIndex] };
		const toSlot = { ...imageSlots[toIndex] };
		
		// Swap the image data (but keep the slot IDs)
		imageSlots[fromIndex] = {
			id: fromSlotId,
			image: toSlot.image,
			filename: toSlot.filename
		};
		
		imageSlots[toIndex] = {
			id: toSlotId,
			image: fromSlot.image,
			filename: fromSlot.filename
		};
		
		// Save the reordered slots
		await saveSlots();
		
		// Delete slideshow.mp4 since images have changed order
		await deleteSlideshow();
		
		onSlotsUpdate?.(imageSlots);
	}
	
	async function saveSlots() {
		try {
			const response = await fetch(`${getApiUrl()}/api/uploads/${projectId}/save-slots`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ slots: imageSlots })
			});
			
			if (!response.ok) {
				console.error('Failed to save slot order');
			}
		} catch (error) {
			console.error('Error saving slots:', error);
		}
	}
</script>

<div class="scavenger-hunt-grid">
	<!-- Batch Upload Button -->
	{#if imageSlots.filter(slot => !slot.image).length >= 2}
		<div class="mb-6 text-center">
			<label class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 cursor-pointer transition-colors {batchUploading ? 'opacity-75 cursor-not-allowed' : ''}">
			<input
				type="file"
				accept="image/*"
				multiple
				onchange={handleBatchFileSelect}
				disabled={batchUploading}
				class="hidden"
			/>
			{#if batchUploading}
				<svg class="animate-spin h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24">
					<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
					<path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
				</svg>
				Uploading {batchUploadProgress.current} of {batchUploadProgress.total}...
			{:else}
				<svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
				</svg>
				Upload Multiple Images (Max 12)
			{/if}
		</label>
		<p class="mt-2 text-sm text-gray-500">
			Select up to 12 images at once, or click individual slots below
		</p>
	</div>
	{/if}

	<div class="grid grid-cols-4 gap-4 max-w-4xl mx-auto">
		{#each imageSlots as slot (slot.id)}
			<div 
				class="slot group aspect-square border-2 border-dashed border-gray-300 rounded-lg relative overflow-hidden transition-all duration-200 hover:border-gray-400 {dragOverSlot === slot.id ? 'border-blue-500 bg-blue-50' : ''} {isDraggingImage && draggedSlot !== slot.id ? 'hover:border-green-500' : ''}"
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
						src={slot.image.startsWith('http') ? slot.image : `${getApiUrl()}${slot.image}`} 
						alt="Slot {slot.id}" 
						class="w-full h-full object-cover cursor-move"
						draggable="true"
						ondragstart={(e) => handleImageDragStart(slot.id, e)}
						ondragend={handleImageDragEnd}
					/>
					
					<!-- Drag Indicator -->
					<div class="absolute bottom-2 right-2 z-10 bg-black bg-opacity-60 text-white p-1 rounded opacity-0 group-hover:opacity-100 transition-opacity">
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l4-4 4 4m0 6l-4 4-4-4"></path>
						</svg>
					</div>
					
					<!-- Remove Button -->
					<button
						onclick={() => removeSlotImage(slot.id)}
						class="absolute top-2 right-2 z-10 bg-red-500 hover:bg-red-600 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs transition-colors"
						title="Remove image"
					>
						×
					</button>
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