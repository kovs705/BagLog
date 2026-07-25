//
//  ProfileView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

//                Section("BagLog account") {
//                    ProfileAuthenticationView()
//                }

struct ProfileView: View {
    
    
    var body: some View {
        innerContent
    }
    
    // MARK: - Components
    @ViewBuilder private var innerContent: some View {
        NavigationStack {
            ScrollView {
                header
            }
            .toolbar(.hidden)
        }
    }
    
    @ViewBuilder private var header: some View {
        VStack {
            smallHeader
            HStack(alignment: .top) {
                infoSection
                imageSection
            }
            description
            divider
            portfolio
        }
        .padding()
    }
    
    @ViewBuilder private var smallHeader: some View {
        Text("MY PROFILE")
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var divider: some View {
        Text("––––")
            .foregroundStyle(.orange)
            .bold()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var infoSection: some View {
        VStack {
            title
            subTitle
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder private var imageSection: some View {
        image
    }
    
    @ViewBuilder private var title: some View {
        Text("Eugene Kovs")
            .font(.largeTitle)
            .bold()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var subTitle: some View {
        HStack {
            Text("@kovs")
                .foregroundStyle(.secondary)
            
            Text("IPHONE 15 PRO MAX")
                .foregroundStyle(.orange)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var description: some View {
        Text("Everyday carry, one-bag traveler, and camera enthusiast.")
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var portfolio: some View {
        Text("8 kits • 3 forks • since Jul '26")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder private var image: some View {
        Image(.userProfile5)
            .resizable()
            .frame(width: 111, height: 111)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                Image(.frame4Aligned)
                    .resizable()
                    .frame(width: 140, height: 140)
                    .scaledToFit()
            }
    }
}

#if DEBUG
#Preview {
    ProfileView()
        .environment(Router())
}
#endif
