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
	
	let dragOverSlot = $state<number | null>(null);
	let draggedSlot = $state<number | null>(null);
	let isDraggingImage = $state(false);
	
	// Enhanced upload queue system
	let uploadQueue = $state<Array<{
		id: string;
		file: File;
		slotId: number;
		status: 'pending' | 'uploading' | 'completed' | 'error';
		progress: number;
		retryCount: number;
		error?: string;
	}>>([]);
	let isProcessingQueue = $state(false);
	let nextUploadId = 0;

	// Get all currently uploaded filenames for duplicate detection
	function getUploadedFilenames(): Set<string> {
		return new Set(
			imageSlots
				.filter(slot => slot.filename)
				.map(slot => slot.filename!)
		);
	}

	function addToUploadQueue(file: File, slotId: number) {
		const uploadedFilenames = getUploadedFilenames();
		
		// Check for duplicate filename
		if (uploadedFilenames.has(file.name)) {
			alert(`Image "${file.name}" is already uploaded in another slot. Please choose a different image.`);
			return false;
		}
		
		// Check if slot is already occupied
		if (imageSlots[slotId - 1].image) {
			alert(`Slot ${slotId} is already occupied. Please choose an empty slot.`);
			return false;
		}
		
		// Check if there's already an upload in queue for this slot
		const existingUpload = uploadQueue.find(upload => 
			upload.slotId === slotId && (upload.status === 'pending' || upload.status === 'uploading')
		);
		if (existingUpload) {
			alert(`Slot ${slotId} already has an upload in progress.`);
			return false;
		}
		
		// Add to queue
		const uploadItem = {
			id: `upload_${nextUploadId++}`,
			file,
			slotId,
			status: 'pending' as const,
			progress: 0,
			retryCount: 0
		};
		
		uploadQueue.push(uploadItem);
		processUploadQueue();
		return true;
	}
	
	async function handleBatchUpload(files: FileList) {
		const uploadedFilenames = getUploadedFilenames();
		const filesToQueue: Array<{file: File, slotId: number}> = [];
		
		// Find empty slots and prepare upload list
		let slotIndex = 0;
		for (let i = 0; i < files.length && filesToQueue.length < 12; i++) {
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
				filesToQueue.push({ file, slotId: slotIndex + 1 });
				uploadedFilenames.add(file.name); // Track to prevent duplicates within batch
				slotIndex++;
			}
		}
		
		if (filesToQueue.length === 0) {
			alert('No available slots or all selected images are already uploaded.');
			return;
		}
		
		// Add all files to queue
		for (const { file, slotId } of filesToQueue) {
			const uploadItem = {
				id: `upload_${nextUploadId++}`,
				file,
				slotId,
				status: 'pending' as const,
				progress: 0,
				retryCount: 0
			};
			uploadQueue.push(uploadItem);
		}
		
		// Start processing the queue
		processUploadQueue();
	}
	
	async function processUploadQueue() {
		if (isProcessingQueue) return;
		
		const pendingUploads = uploadQueue.filter(upload => upload.status === 'pending');
		if (pendingUploads.length === 0) return;
		
		isProcessingQueue = true;
		
		// Process uploads sequentially to avoid overwhelming the backend
		for (const upload of pendingUploads) {
			if (upload.status !== 'pending') continue;
			
			upload.status = 'uploading';
			uploadQueue = uploadQueue; // Trigger reactivity
			
			const success = await performSlotUpload(upload);
			
			if (success) {
				upload.status = 'completed';
				upload.progress = 100;
				
				// Remove completed upload after delay
				setTimeout(() => {
					uploadQueue = uploadQueue.filter(u => u.id !== upload.id);
				}, 2000);
			} else {
				// Handle retry logic
				if (upload.retryCount < 2) {
					upload.retryCount++;
					upload.status = 'pending';
					upload.progress = 0;
					console.log(`Retrying upload for slot ${upload.slotId}, attempt ${upload.retryCount + 1}`);
				} else {
					upload.status = 'error';
					upload.error = 'Upload failed after 3 attempts';
				}
			}
			
			uploadQueue = uploadQueue; // Trigger reactivity
			
			// Small delay between uploads to be gentle on the server
			await new Promise(resolve => setTimeout(resolve, 500));
		}
		
		isProcessingQueue = false;
		
		// If there are still pending uploads (from retries), process them
		const stillPending = uploadQueue.filter(upload => upload.status === 'pending');
		if (stillPending.length > 0) {
			setTimeout(() => processUploadQueue(), 1000);
		}
	}

	async function performSlotUpload(upload: {
		id: string;
		file: File;
		slotId: number;
		status: 'pending' | 'uploading' | 'completed' | 'error';
		progress: number;
		retryCount: number;
		error?: string;
	}): Promise<boolean> {
		try {
			const formData = new FormData();
			formData.append('images', upload.file);
			formData.append('slot', upload.slotId.toString());

			const xhr = new XMLHttpRequest();
			
			// Track upload progress
			xhr.upload.addEventListener('progress', (e) => {
				if (e.lengthComputable) {
					upload.progress = (e.loaded / e.total) * 100;
					uploadQueue = uploadQueue; // Trigger reactivity
				}
			});

			const uploadPromise = new Promise<boolean>((resolve) => {
				xhr.addEventListener('load', async () => {
					if (xhr.status === 200) {
						try {
							const result = JSON.parse(xhr.responseText);
							const slotIndex = upload.slotId - 1;
							imageSlots[slotIndex] = {
								id: upload.slotId,
								image: result.file?.url || `/api/files/${projectId}/${result.filename}`,
								filename: result.filename
							};
							
							// Delete slideshow.mp4 since images have changed
							await deleteSlideshow();
							
							onSlotsUpdate?.(imageSlots);
							resolve(true);
						} catch (parseError) {
							console.error('Failed to parse response:', parseError);
							upload.error = 'Invalid server response';
							resolve(false);
						}
					} else {
						try {
							const error = JSON.parse(xhr.responseText);
							upload.error = error.error || 'Upload failed';
						} catch {
							upload.error = `Upload failed with status ${xhr.status}`;
						}
						resolve(false);
					}
				});

				xhr.addEventListener('error', () => {
					upload.error = 'Network error during upload';
					resolve(false);
				});
			});

			xhr.open('POST', `${getApiUrl()}/api/uploads/${projectId}/scavenger-hunt-slot`);
			xhr.send(formData);
			
			return await uploadPromise;
		} catch (error) {
			console.error('Upload error:', error);
			upload.error = error instanceof Error ? error.message : 'Unknown error';
			return false;
		}
	}
	
	// Updated function for single slot uploads (from file input or drag & drop)
	async function handleSlotUpload(slotId: number, file: File): Promise<boolean> {
		return addToUploadQueue(file, slotId);
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
		const files = input.files;
		if (files && files.length > 0) {
			if (files.length === 1) {
				// Single file - upload to the selected slot
				handleSlotUpload(slotId, files[0]);
			} else {
				// Multiple files - queue them starting from the selected slot
				handleMultipleFilesFromSlot(slotId, files);
			}
		}
		// Reset input to allow re-uploading same files
		input.value = '';
	}
	
	function handleMultipleFilesFromSlot(startSlotId: number, files: FileList) {
		const uploadedFilenames = getUploadedFilenames();
		const filesToQueue: Array<{file: File, slotId: number}> = [];
		
		// Start from the selected slot and find available slots
		let currentSlotIndex = startSlotId - 1;
		
		for (let i = 0; i < files.length && filesToQueue.length < 12; i++) {
			const file = files[i];
			
			// Skip duplicate filenames
			if (uploadedFilenames.has(file.name)) {
				console.log(`Skipping duplicate file: ${file.name}`);
				continue;
			}
			
			// Find next available slot starting from currentSlotIndex
			while (currentSlotIndex < 12 && imageSlots[currentSlotIndex].image) {
				currentSlotIndex++;
			}
			
			if (currentSlotIndex < 12) {
				filesToQueue.push({ file, slotId: currentSlotIndex + 1 });
				uploadedFilenames.add(file.name); // Track to prevent duplicates within batch
				currentSlotIndex++; // Move to next slot for next file
			} else {
				// No more available slots
				break;
			}
		}
		
		if (filesToQueue.length === 0) {
			alert('No available slots or all selected images are already uploaded.');
			return;
		}
		
		if (filesToQueue.length < files.length) {
			const skipped = files.length - filesToQueue.length;
			alert(`Queuing ${filesToQueue.length} files. ${skipped} files were skipped (no available slots or duplicates).`);
		}
		
		// Add all files to queue
		for (const { file, slotId } of filesToQueue) {
			const uploadItem = {
				id: `upload_${nextUploadId++}`,
				file,
				slotId,
				status: 'pending' as const,
				progress: 0,
				retryCount: 0
			};
			uploadQueue.push(uploadItem);
		}
		
		// Start processing the queue
		processUploadQueue();
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
			// Filter for image files only
			const imageFiles = Array.from(files).filter(file => 
				file.type.startsWith('image/') || file.name.toLowerCase().endsWith('.heic')
			);
			
			if (imageFiles.length === 0) {
				alert('Please upload image files only (JPEG, PNG, HEIC, etc.)');
				return;
			}
			
			if (imageFiles.length === 1) {
				// Single file - upload to the dropped slot
				handleSlotUpload(slotId, imageFiles[0]);
			} else {
				// Multiple files - queue them starting from the dropped slot
				const fileList = new DataTransfer();
				imageFiles.forEach(file => fileList.items.add(file));
				handleMultipleFilesFromSlot(slotId, fileList.files);
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
		
		// Trigger reactivity
		imageSlots = imageSlots;
		
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
				console.error('Failed to save slot order:', response.status, response.statusText);
			}
		} catch (error) {
			console.error('Error saving slots:', error);
		}
	}
</script>

<div class="scavenger-hunt-grid">

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
				{:else if uploadQueue.find(upload => upload.slotId === slot.id && (upload.status === 'uploading' || upload.status === 'pending'))}
					{@const upload = uploadQueue.find(upload => upload.slotId === slot.id && (upload.status === 'uploading' || upload.status === 'pending'))}
					<!-- Uploading State -->
					<div class="flex flex-col items-center justify-center h-full text-gray-500">
						{#if upload?.status === 'uploading'}
							<svg class="animate-spin h-8 w-8 mb-2" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							<span class="text-sm">Uploading... {Math.round(upload.progress)}%</span>
							<div class="w-16 bg-gray-200 rounded-full h-1 mt-1">
								<div class="bg-blue-500 h-1 rounded-full transition-all duration-300" style="width: {upload.progress}%"></div>
							</div>
						{:else}
							<svg class="h-8 w-8 mb-2 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
							</svg>
							<span class="text-sm">In Queue...</span>
							{#if upload?.retryCount > 0}
								<span class="text-xs text-orange-600">Retry {upload.retryCount + 1}</span>
							{/if}
						{/if}
					</div>
				{:else}
					<!-- Empty Slot -->
					<label class="flex flex-col items-center justify-center h-full cursor-pointer text-gray-400 hover:text-gray-600 transition-colors">
						<input
							type="file"
							accept="image/*"
							multiple
							onchange={(e) => handleFileSelect(slot.id, e)}
							class="hidden"
						/>
						<svg class="w-12 h-12 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
						</svg>
						<span class="text-sm text-center px-2">
							Add Image(s)<br>
							<span class="text-xs">or drag & drop multiple</span>
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