import Foundation

@main
struct ScanTestRunner {
    static func main() async {
        print("Starting Scan Service Test...")
        
        let service = DockerService.shared
        
        // Mocking a scan by calling scanImage with a known image if exists, or just checking if it fails gracefully
        do {
            let images = try await service.listImages()
            if let first = images.first {
                print("Attempting to scan \(first.name)...")
                do {
                    let result = try await service.scanImage(first.imageID)
                    print("Scan result length: \(result.count)")
                } catch {
                    print("Scan failed as expected (if trivy missing): \(error)")
                }
            } else {
                print("No images to scan.")
            }
        } catch {
            print("List images failed: \(error)")
        }
    }
}
