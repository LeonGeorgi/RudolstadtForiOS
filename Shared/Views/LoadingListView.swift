import SwiftUI

struct LoadingListView<ListValues, ListView: View> : View where ListValues : RandomAccessCollection {
    var noDataMessage: LocalizedStringKey
    var noDataSubtitle: String? = nil
    var dataMapper: (Entities) -> ListValues
    var listView: (ListValues) -> ListView
    

    @EnvironmentObject var dataStore: DataStore

    var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    var noDataView: some View {
        VStack {
            Spacer()
            VStack {
                Text(noDataMessage)
                        .padding(.bottom)
                if let subtitle = noDataSubtitle {
                    Text(subtitle)
                }
            }
                    .padding()
            Spacer()
        }
    }

    func failureView(_ reason: FailureReason) -> some View {
        VStack {
            Spacer()
            VStack {
                Text(reason.rawValue)
                        .padding(.bottom)
                Button {
                    Task {
                        await retry()
                    }
                } label: {
                    Text("list.reload")
                }
            }
                    .padding()
            Spacer()
        }
    }

    func retry() async {
        await dataStore.loadData()
    }

    var body: some View {
        switch dataStore.data {
        case .loading:
            loadingView
        case .failure(let reason):
            failureView(reason)
        case .success(let entities):
            let listValues = dataMapper(entities)
            if listValues.isEmpty {
                noDataView
            } else {
                listView(listValues)
            }
        }
    }
}
