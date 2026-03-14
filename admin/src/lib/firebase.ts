import { initializeApp } from 'firebase/app'
import { getFirestore } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: 'AIzaSyAH9A4mxNvTtgbL2kf1Dr4tCj5JdVpcPfw',
  appId: '1:1085571193268:web:08189a9bc1154d5ea5bae1',
  messagingSenderId: '1085571193268',
  projectId: 'gradready-5033e',
  authDomain: 'gradready-5033e.firebaseapp.com',
  storageBucket: 'gradready-5033e.firebasestorage.app',
  measurementId: 'G-LLL1VR5NZZ',
}

const app = initializeApp(firebaseConfig)
export const db = getFirestore(app)
