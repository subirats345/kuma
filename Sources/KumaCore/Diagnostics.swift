import Foundation

func describe(_ error: Error) -> String {
    if let error = error as? KumaError {
        return error.description
    }
    return error.localizedDescription
}
