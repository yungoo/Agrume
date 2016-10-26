//
//  ImageDownloader.swift
//  Agrume
//

import Foundation

class ImageDownloader {
    
    class func downloadImage(_ url: URL, completion: @escaping (_ image: UIImage?) -> Void) -> URLSessionDataTask {
        let session = URLSession.shared
        let request = URLRequest(url: url)
        let dataTask = session.dataTask(with: request, completionHandler: {
            data, _, error in
            if error != nil {
                completion(nil)
                return
            }
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.high).async {
                if let image = UIImage(data: data!) {
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    completion(nil)
                }
            }
        })
        dataTask.resume()
        return dataTask
    }
    
}
