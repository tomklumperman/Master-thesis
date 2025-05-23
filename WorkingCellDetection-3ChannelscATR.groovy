import qupath.lib.objects.PathObject
import qupath.lib.objects.PathCellObject
import qupath.lib.objects.PathAnnotationObject
import qupath.lib.objects.PathDetectionObject
import qupath.lib.measurements.MeasurementList
import qupath.lib.roi.ROIs
import qupath.lib.io.PathIO

setImageType('FLUORESCENCE')

// Retrieve the root annotation
def rootAnnotationName = 'Root'  // Annotation name is lowercase 'root'
def root = getAnnotationObjects().find { it.getName().equals(rootAnnotationName) }

// specify channels
def Channel1 = 'AF488'
def Channel2 = 'AF647'
def Channel3 = 'Cy3'

// Check if root annotation exists
if (root == null) {
    print("Root annotation named '${rootAnnotationName}' not found. Please check the available annotations.")
    return
}
// get image data name for csv output name
def imageData = getCurrentImageData()
def server = imageData.getServer()
def imageName = server.getMetadata().getName()
def safeImageName = imageName.replaceAll("[^a-zA-Z0-9]","_")

// Duplicate root annotation for detection
def regionMeasured = PathObjectTools.transformObject(root, null, true)
regionMeasured.setName("Measured Region")
addObject(regionMeasured)
setSelectedObject(regionMeasured)

// Run cell detection
clearDetections()

// specify detection parameters per channel
// Change these parameters dependent on data. check manually what are the best parameters
def paramsCh1 = [
    detectionImage: Channel1,
    requestedPixelSizeMicrons: 0.5,
    backgroundRadiusMicrons: 8.0,
    sigmaMicrons: 1.5,
    minAreaMicrons: 35.0,
    maxAreaMicrons: 300.0,
    threshold: 60.0,
    watershedPostProcess: true,
    cellExpansionMicrons: 0,
    includeNuclei: true,
    smoothBoundaries: true,
    makeMeasurements: true
]
// Change these parameters dependent on data. check manually what are the best parameters   
def paramsCh2 = [
    detectionImage: Channel2,
    requestedPixelSizeMicrons: 0.5,
    backgroundRadiusMicrons: 8.0,
    sigmaMicrons: 1.5,
    minAreaMicrons: 50.0,
    maxAreaMicrons: 360.0,
    threshold: 30.0,
    watershedPostProcess: true,
    cellExpansionMicrons: 0,
    includeNuclei: true,
    smoothBoundaries: true,
    makeMeasurements: true
]

def paramsCh3 = [
    detectionImage: Channel3,
    requestedPixelSizeMicrons: 0.5,
    backgroundRadiusMicrons: 8.0,
    sigmaMicrons: 1.5,
    minAreaMicrons: 60.0,
    maxAreaMicrons: 360.0,
    threshold: 160.0,
    watershedPostProcess: true,
    cellExpansionMicrons: 0,
    includeNuclei: true,
    smoothBoundaries: true,
    makeMeasurements: true
]

// run the cell detections with parameters specified above
runPlugin('qupath.imagej.detect.cells.WatershedCellDetection', paramsCh1)
def af488Cells = getDetectionObjects().toList()
// assign af488 label to all detection objects
af488Cells.each { cell -> cell.setPathClass(getPathClass(Channel1)) }

runPlugin('qupath.imagej.detect.cells.WatershedCellDetection', paramsCh2)
def Cy3Cells = getDetectionObjects().toList()
// assign Cy3 label to all detection objects
Cy3Cells.each { cell -> cell.setPathClass(getPathClass(Channel2)) }

runPlugin('qupath.imagej.detect.cells.WatershedCellDetection', paramsCh3)
def Cy5Cells = getDetectionObjects().toList()
// assign Cy5 label to all detection objects
Cy5Cells.each { cell -> cell.setPathClass(getPathClass(Channel3)) }

// add all deteccted cells back to the image to make them visible
addObjects(af488Cells + Cy3Cells + Cy5Cells)

// ensure the UI updates to show all detections
fireHierarchyUpdate()

// Get all detected cells
def allCells = af488Cells + Cy3Cells + Cy5Cells

// Get all annotations (excluding the root annotation)
def annotations = getAnnotationObjects().findAll { it.getParent() != null }

// Prepare CSV data
def csvData = []
def csvHeader = ["Cell_ID","SmallestRegion","ParentRegion","Fluorescence", "X", "Y", "Area"]
def measurementNames = allCells[0]?.getMeasurementList()?.getMeasurementNames()

if (measurementNames) {
    csvHeader.addAll(measurementNames)  // Add all measurement names dynamically
}

// Process each cell
allCells.eachWithIndex { cell, index ->
    def cellX = cell.getROI().getCentroidX()
    def cellY = cell.getROI().getCentroidY()
    def cellArea = cell.getROI().getArea()
    def cellFluorescence = cell.getPathClass()?.toString() ?: "Unknown"

    // Find the **smallest** annotation containing this cell
    def containingAnnotations = annotations.findAll { it.getROI().contains(cellX, cellY) }
    def smallestAnnotation = containingAnnotations.sort { it.getROI().getArea() }.first()  // Sort by area and pick the smallest
    def annotationName = smallestAnnotation ? smallestAnnotation.getName() : "None"
    def parentAnnotation = smallestAnnotation.getParent()
    def parentName = parentAnnotation ? parentAnnotation.getName() : "None"

    // Store data
    csvData.add("${index + 1},${annotationName},${parentName},${cellFluorescence},${cellX},${cellY}")
}

// Define output path for CSV
def outputFilePath = buildFilePath("X:/Tom/Master/Registrations cATR/CN-HDB-VDB/cell-counting_output-M25-00773-02", safeImageName + ".csv")

// Write data to CSV file
def file = new File(outputFilePath)
file.text = csvHeader + "\n" + csvData.join("\n")

println "CSV file saved at: " + outputFilePath