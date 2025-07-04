// import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// import { Resend } from 'https://esm.sh/resend@3.2.0';
// console.log("Edge Function 'notify-all-users' is initializing.");
// Deno.serve(async (req)=>{
//   try {
//     // 1. Ambil data event dari request yang dikirim oleh Trigger Postgres
//     const { record } = await req.json();
//     console.log(`New event received for device: ${record.device_id}`);
//     // 2. Ambil Kunci API Resend dari environment variables
//     const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
//     if (!RESEND_API_KEY) {
//       throw new Error("RESEND_API_KEY is not set in Supabase secrets.");
//     }
//     const resend = new Resend(RESEND_API_KEY);
//     // 3. Buat Supabase client di dalam Edge Function untuk mengambil daftar email
//     const supabaseAdmin = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
//     // 4. Ambil semua email dari tabel 'profiles'
//     const { data: profiles, error: profileError } = await supabaseAdmin.from('profiles').select('email');
//     if (profileError) {
//       throw new Error(`Failed to fetch profiles: ${profileError.message}`);
//     }
//     if (!profiles || profiles.length === 0) {
//       console.log("No user profiles found to notify.");
//       return new Response(JSON.stringify({
//         message: "No users to notify."
//       }), {
//         headers: {
//           "Content-Type": "application/json"
//         },
//         status: 200
//       });
//     }
//     const emails = profiles.map((p)=>p.email).filter(Boolean); // Ambil email dan filter null/kosong
//     console.log(`Found ${emails.length} emails to notify:`, emails);
//     // 5. Kirim email ke semua pengguna menggunakan Resend
//     const { data, error } = await resend.emails.send({
//       from: 'Sistem Smart Anti Theft <onboarding@resend.dev>',
//       to: emails,
//       subject: `⚠️ Peringatan Ancaman: Terdeteksi ${record.event_type} di ${record.location_name}!`,
//       html: `
//         <h1>Peringatan Ancaman</h1>
//         <p>Halo,</p>
//         <p>Sistem kami telah mendeteksi adanya <strong>${record.event_type}</strong> pada perangkat <strong>${record.device_id}</strong> yang berlokasi di <strong>${record.location_name}</strong>.</p>
//         <p>Sebuah gambar telah berhasil ditangkap sebagai referensi.</p>
//         <img src="${record.image_ref}" alt="Captured Image" style="max-width: 400px; border-radius: 8px;" />
//         <p>Silakan periksa aplikasi Anda untuk detail lebih lanjut.</p>
//         <br/>
//         <p>Terima kasih,</p>
//         <p>Tim Keamanan Cerdas Anda</p>
//       `
//     });
//     if (error) {
//       console.error("Error sending email:", error);
//       throw new Error(JSON.stringify(error));
//     }
//     console.log("Successfully sent emails:", data);
//     return new Response(JSON.stringify({
//       data
//     }), {
//       headers: {
//         "Content-Type": "application/json"
//       },
//       status: 200
//     });
//   } catch (error) {
//     console.error("Critical error in Edge Function:", error.message);
//     return new Response(JSON.stringify({
//       error: error.message
//     }), {
//       headers: {
//         "Content-Type": "application/json"
//       },
//       status: 500
//     });
//   }
// });
