<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { getApiUrl } from '$lib/config';
	
	interface Props {
		projectId: string;
	}
	
	let { projectId }: Props = $props();
	const dispatch = createEventDispatcher();
	
	let isDragging = $state(false);
	let uploadQueue = $state<{ file: File, id: string, progress: number, status: 'pending' | 'uploading' | 'completed' | 'error' }[]>([]);
	let fileInput: HTMLInputElement;
	let nextUploadId = 0;
	
	function handleDragOver(e: DragEvent) {
		e.preventDefault();
		isDragging = true;
	}
	
	function handleDragLeave() {
		isDragging = false;
	}
	
	function handleDrop(e: DragEvent) {
		e.preventDefault();
		isDragging = false;
		
		const files = Array.from(e.dataTransfer?.files || []);
		handleFiles(files);
	}
	
	function handleFileSelect(e: Event) {
		const target = e.target as HTMLInputElement;
		const files = Array.from(target.files || []);
		handleFiles(files);
	}
	
	async function handleFiles(files: File[]) {
		const imageFiles = files.filter(file => 
			file.type.startsWith('image/') || file.name.toLowerCase().endsWith('.heic')
		);
		
		if (imageFiles.length === 0) {
			alert('Please select image files only');
			return;
		}
		
		// Add files to upload queue
		const newUploads = imageFiles.map(file => ({
			file,
			id: `upload_${nextUploadId++}`,
			progress: 0,
			status: 'pending' as const
		}));
		
		uploadQueue.push(...newUploads);
		
		// Process queue (allows concurrent uploads)
		processUploadQueue();
	}
	
	async function processUploadQueue() {
		const pendingUploads = uploadQueue.filter(upload => upload.status === 'pending');
		
		// Process multiple uploads concurrently (limit to 3 at a time)
		const maxConcurrent = 3;
		const currentUploading = uploadQueue.filter(upload => upload.status === 'uploading').length;
		const canStart = Math.min(maxConcurrent - currentUploading, pendingUploads.length);
		
		for (let i = 0; i < canStart; i++) {
			const upload = pendingUploads[i];
			upload.status = 'uploading';
			uploadSingleFile(upload);
		}
	}
	
	async function uploadSingleFile(upload: { file: File, id: string, progress: number, status: 'pending' | 'uploading' | 'completed' | 'error' }) {
		const formData = new FormData();
		formData.append('images', upload.file);
		
		try {
			const xhr = new XMLHttpRequest();
			
			xhr.upload.addEventListener('progress', (e) => {
				if (e.lengthComputable) {
					upload.progress = (e.loaded / e.total) * 100;
					uploadQueue = uploadQueue; // Trigger reactivity
				}
			});
			
			xhr.addEventListener('load', () => {
				if (xhr.status === 200) {
					upload.status = 'completed';
					upload.progress = 100;
					
					// Remove completed upload after a short delay
					setTimeout(() => {
						uploadQueue = uploadQueue.filter(u => u.id !== upload.id);
						
						// Dispatch uploaded event when all uploads are complete
						if (uploadQueue.every(u => u.status === 'completed' || u.status === 'error')) {
							dispatch('uploaded');
							fileInput.value = '';
						}
					}, 1000);
					
					// Process next items in queue
					processUploadQueue();
				} else {
					upload.status = 'error';
					console.error('Upload failed:', xhr.responseText);
				}
				uploadQueue = uploadQueue; // Trigger reactivity
			});
			
			xhr.addEventListener('error', () => {
				upload.status = 'error';
				uploadQueue = uploadQueue; // Trigger reactivity
				console.error('Upload error for file:', upload.file.name);
				
				// Process next items in queue
				processUploadQueue();
			});
			
			xhr.open('POST', `${getApiUrl()}/api/upload/${projectId}/images`);
			xhr.send(formData);
		} catch (error) {
			console.error('Upload error:', error);
			upload.status = 'error';
			uploadQueue = uploadQueue; // Trigger reactivity
			
			// Process next items in queue
			processUploadQueue();
		}
	}
</script>

<div
	class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-dashed rounded-lg transition-colors {isDragging ? 'border-indigo-400 bg-indigo-50' : 'border-gray-300'}"
	ondragover={handleDragOver}
	ondragleave={handleDragLeave}
	ondrop={handleDrop}
>
	<div class="space-y-1 text-center">
		<svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
			<path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
		</svg>
		<div class="flex text-sm text-gray-600">
			<label for="file-upload" class="relative cursor-pointer rounded-md font-medium text-indigo-600 hover:text-indigo-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-indigo-500">
				<span>Upload files</span>
				<input
					bind:this={fileInput}
					id="file-upload"
					name="file-upload"
					type="file"
					class="sr-only"
					multiple
					accept="image/*,.heic"
					onchange={handleFileSelect}
				/>
			</label>
			<p class="pl-1">or drag and drop</p>
		</div>
		<p class="text-xs text-gray-500">
			PNG, JPG, GIF, HEIC up to 100MB each
		</p>
		
		{#if uploadQueue.length > 0}
			<div class="mt-4 space-y-2">
				{#each uploadQueue as upload (upload.id)}
					<div class="bg-gray-50 rounded-lg p-3">
						<div class="flex items-center justify-between mb-2">
							<span class="text-sm text-gray-700 truncate flex-1 mr-2">
								{upload.file.name}
							</span>
							<span class="text-xs px-2 py-1 rounded-full {
								upload.status === 'uploading' ? 'bg-blue-100 text-blue-800' :
								upload.status === 'completed' ? 'bg-green-100 text-green-800' :
								upload.status === 'error' ? 'bg-red-100 text-red-800' :
								'bg-gray-100 text-gray-800'
							}">
								{upload.status === 'uploading' ? 'Uploading' :
								 upload.status === 'completed' ? 'Complete' :
								 upload.status === 'error' ? 'Error' :
								 'Pending'}
							</span>
						</div>
						<div class="bg-gray-200 rounded-full h-2">
							<div 
								class="h-2 rounded-full transition-all duration-300 {
									upload.status === 'completed' ? 'bg-green-500' :
									upload.status === 'error' ? 'bg-red-500' :
									'bg-blue-500'
								}"
								style="width: {upload.progress}%"
							></div>
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
