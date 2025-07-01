# Slideshow Webapp Changelog

## [Latest] - 2025-07-01

### Added - Multiple Project Types & Audio Processing

#### 🎨 **Three Project Types with Distinct Interfaces**
- **FWI Main** - Standard slideshow creation with images and audio
- **FWI Emotional** - Emotional slideshow variant with purple theming
- **Scavenger Hunt** - Image-only slideshow with green theming (no audio required)

#### 🎵 **Enhanced Audio Processing**
- **Madmom Processing for All Audio Uploads**: Added automatic downbeat detection for regular audio file uploads (previously only available for YouTube downloads)
- **Terminal Logging**: Comprehensive terminal output showing madmom processing progress for both file uploads and YouTube downloads
- **Background Processing**: Audio uploads complete immediately, madmom runs in background
- **Fallback Methods**: Multiple madmom execution strategies (conda environment, Python 3.10+ compatibility, python3.9, bash wrapper)

#### 🛠 **Backend Improvements**
- **Project Type Storage**: Projects now store and validate type metadata (`FWI-main`, `FWI-emotional`, `Scavenger-Hunt`)
- **Enhanced API Responses**: Upload endpoints now indicate when background processing has started
- **Metadata Updates**: Downbeat detection results saved to project metadata

#### 🎯 **Frontend Enhancements**
- **Project Creation with Type Selection**: Dropdown to choose project type during creation
- **Type-Specific Routing**: 
  - `/fwi-main/[id]` for FWI Main projects
  - `/fwi-emotional/[id]` for FWI Emotional projects  
  - `/scavenger-hunt/[id]` for Scavenger Hunt projects
- **Visual Differentiation**: Color-coded project badges and themed interfaces
- **Smart Navigation**: Automatic routing to correct interface based on project type
- **Project Type Display**: Project type prominently shown in headers and project lists

#### 🔧 **UI/UX Improvements**
- **Auto-Navigation After Creation**: New projects automatically navigate to project page
- **Better Error Handling**: User-friendly error messages for non-existent projects
- **Type Validation**: Routes redirect if project type doesn't match URL
- **Themed Interfaces**: Each project type has distinct color schemes and button text

### Modified

#### 🎨 **Scavenger Hunt Specific Changes**
- **Removed Audio Requirements**: No audio upload needed for Scavenger Hunt projects
- **Simplified Interface**: "Images & Audio" tab changed to just "Images"
- **Updated Generation Logic**: "Generate Hunt Slideshow" button appears with images only
- **Clean Workflow**: Streamlined image-only workflow for hunt-style slideshows

#### 🔄 **Project Management**
- **Enhanced Project List**: Shows project types with color-coded badges
- **Type-Aware Navigation**: Project links route to appropriate interface
- **Backward Compatibility**: Legacy projects default to FWI-main type

### Technical Details

#### 📁 **File Structure Changes**
```
frontend/my-app/src/routes/
├── fwi-main/[id]/+page.svelte          # FWI Main interface
├── fwi-emotional/[id]/+page.svelte     # FWI Emotional interface  
├── scavenger-hunt/[id]/+page.svelte    # Scavenger Hunt interface
└── project/[id]/+page.svelte           # Legacy/fallback interface
```

#### 🔧 **Backend API Updates**
- **POST /api/projects**: Now accepts `type` parameter
- **GET /api/projects**: Returns project type in response
- **POST /api/upload/:projectId/audio**: Enhanced with madmom processing and terminal logging

#### 🎨 **Component Updates**
- **CreateProject.svelte**: Added project type selection and smart routing
- **ProjectList.svelte**: Added type display and type-aware navigation  
- **AudioUpload.svelte**: Enhanced with processing status messages
- **uploads.js**: Added comprehensive madmom processing for all audio uploads

#### 🎯 **Processing Features**
- **Madmom Integration**: Downbeat detection for all audio uploads
- **Multi-Method Execution**: Conda environment, compatibility scripts, fallback options
- **Real-time Logging**: Terminal output format: `[projectId] step: message`
- **Error Handling**: Graceful fallbacks when madmom processing fails

### Color Schemes
- **FWI Main**: Blue theme (`bg-blue-100 text-blue-800`, `bg-indigo-600`)
- **FWI Emotional**: Purple theme (`bg-purple-100 text-purple-800`, `bg-purple-600`)  
- **Scavenger Hunt**: Green theme (`bg-green-100 text-green-800`, `bg-green-600`)

### Compatibility
- **Legacy Support**: Existing projects work with new system
- **Route Fallbacks**: Invalid routes redirect appropriately
- **Type Defaults**: Projects without type metadata default to FWI-main

---

## Development Notes

### Next Steps
- [ ] Customize FWI Emotional interface for emotional analysis features
- [ ] Add scavenger hunt specific features (clues, locations, etc.)
- [ ] Enhance madmom processing with more audio analysis features
- [ ] Add project type filtering to project list
- [ ] Implement type-specific slideshow generation logic

### Known Issues
- Madmom processing may fail on systems without proper Python environment setup
- WebSocket updates may not reflect madmom completion status immediately
- Some legacy projects may need metadata migration for full type support