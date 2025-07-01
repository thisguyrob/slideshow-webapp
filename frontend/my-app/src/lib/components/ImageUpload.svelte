<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	
	interface Props {
		projectId: string;
	}
	
	let { projectId }: Props = $props();
	const dispatch = createEventDispatcher();
	
	let isDragging = $state(false);
	let uploading = $state(false);
	let uploadProgress = $state(0);
	let fileInput: HTMLInputElement;
	
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
		
		uploading = true;
		uploadProgress = 0;
		
		const formData = new FormData();
		imageFiles.forEach(file => {
			formData.append('images', file);
		});
		
		try {
			const xhr = new XMLHttpRequest();
			
			xhr.upload.addEventListener('progress', (e) => {
				if (e.lengthComputable) {
					uploadProgress = (e.loaded / e.total) * 100;
				}
			});
			
			xhr.addEventListener('load', () => {
				if (xhr.status === 200) {
					dispatch('uploaded');
					fileInput.value = '';
				} else {
					alert('Upload failed. Please try again.');
				}
				uploading = false;
			});
			
			xhr.addEventListener('error', () => {
				alert('Upload failed. Please try again.');
				uploading = false;
			});
			
			xhr.open('POST', `http://localhost:3000/api/upload/${projectId}/images`);
			xhr.send(formData);
		} catch (error) {
			console.error('Upload error:', error);
			alert('Upload failed. Please try again.');
			uploading = false;
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
					disabled={uploading}
				/>
			</label>
			<p class="pl-1">or drag and drop</p>
		</div>
		<p class="text-xs text-gray-500">
			PNG, JPG, GIF, HEIC up to 100MB each
		</p>
		
		{#if uploading}
			<div class="mt-4">
				<div class="bg-gray-200 rounded-full h-2 w-48 mx-auto">
					<div 
						class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
						style="width: {uploadProgress}%"
					></div>
				</div>
				<p class="text-sm text-gray-600 mt-2">Uploading... {Math.round(uploadProgress)}%</p>
			</div>
		{/if}
	</div>
</div>
</script>