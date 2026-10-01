import SwiftUI
import UIKit

struct MonthYearPicker: UIViewRepresentable {
    @Binding var month: Int
    @Binding var year: Int

    private let firstYear = 1900

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        picker.selectRow(month - 1, inComponent: 0, animated: false)
        picker.selectRow(context.coordinator.currentYear - year, inComponent: 1, animated: false)
        return picker
    }

    func updateUIView(_ picker: UIPickerView, context: Context) {
        context.coordinator.parent = self
        if picker.selectedRow(inComponent: 0) != month - 1 {
            picker.selectRow(month - 1, inComponent: 0, animated: false)
        }
        let yearRow = context.coordinator.currentYear - year
        if picker.selectedRow(inComponent: 1) != yearRow {
            picker.selectRow(yearRow, inComponent: 1, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: MonthYearPicker
        let currentYear = Calendar.current.component(.year, from: Date())
        private let monthNames = Calendar.current.monthSymbols

        init(_ parent: MonthYearPicker) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? 12 : currentYear - parent.firstYear + 1
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            pickerView.bounds.width / 2
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            component == 0 ? monthNames[row] : String(currentYear - row)
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                parent.month = row + 1
            } else {
                parent.year = currentYear - row
            }
        }
    }
}
