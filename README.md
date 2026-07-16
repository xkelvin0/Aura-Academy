# 🎓 Aura Academy - La Evolución de la EdTech

Aura Academy es una plataforma de e-learning de próxima generación multiplataforma (Android, iOS y Windows), diseñada para erradicar el aburrimiento digital y la deserción estudiantil mediante Inteligencia Artificial y Gamificación Inmersiva.

## 🚀 Características Principales

*   🤖 **Tutor Contextual (Aura AI 2.0):** Integración con Groq API (modelos Llama) que comprende en qué lección y curso se encuentra el estudiante para brindar respuestas académicas precisas.
*   🏆 **Gamificación Avanzada:** Sistema de progreso basado en Misiones (Aura Quests), Rachas (Streaks) y Medallas, impulsado de forma segura por Triggers en PostgreSQL (Supabase).
*   🌍 **League of Leaders:** Tablas de clasificación globales dinámicas, donde los estudiantes compiten en base a horas de estudio efectivas y consistencia.
*   💻 **Ecosistema Multiplataforma:** Reproductor de video inteligente que renderiza de manera nativa y fluida tanto en entornos Móviles como en Escritorio (Windows).
*   👨‍🏫 **Panel de Instructor Integral:** Gestión de cursos, módulos, lecciones y estadísticas en tiempo real (Inscripciones, Graduaciones).

## 🛠️ Stack Tecnológico

*   **Frontend:** Flutter (Dart) - *Clean Architecture / Feature-Driven*
*   **Backend Serverless:** Supabase (PostgreSQL, Auth, Storage)
*   **Inteligencia Artificial:** Groq API (LLMs)
*   **Seguridad:** Autenticación por JWT encriptado, y Zero-Trust mediante RLS.

## 📂 Estructura del Proyecto

*   `/lib/screens`: Vistas UI modulares separadas por dominio (cursos, perfil, auth, instructor).
*   `/lib/widgets`: Componentes visuales reutilizables (Botones, Tarjetas, ChatBot).
*   `/lib/services`: Servicios de comunicación externa (SupabaseService, GroqService).
*   `/lib/models`: Estructuras de datos puras.
*   `/docs_y_recursos`: Documentación de defensa técnica, presentaciones y recursos SQL.

## 🛡️ Seguridad (Zero-Trust)
Toda la lógica de evaluación, emisión de certificados y adjudicación de medallas ocurre en el backend mediante procedimientos almacenados y disparadores SQL (Triggers) para evitar manipulaciones en el cliente (Anti-Cheat).

---
*Desarrollado para redefinir el aprendizaje interactivo y competitivo.*
