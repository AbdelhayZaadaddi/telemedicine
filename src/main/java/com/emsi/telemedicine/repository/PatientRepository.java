package com.emsi.telemedicine.repository;

import com.emsi.telemedicine.entity.Patient;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class PatientRepository {

    @PersistenceContext(unitName = "telemedicinePU")
    private EntityManager em;

    public List<Patient> findAll() {
        return em.createQuery("SELECT p FROM Patient p ORDER BY p.nom, p.prenom", Patient.class)
                .getResultList();
    }

    public Optional<Patient> findById(Long id) {
        return Optional.ofNullable(em.find(Patient.class, id));
    }

    public Optional<Patient> findByEmail(String email) {
        return em.createQuery("SELECT p FROM Patient p WHERE LOWER(p.email) = LOWER(:email)", Patient.class)
                .setParameter("email", email)
                .getResultStream()
                .findFirst();
    }

    public Patient save(Patient patient) {
        if (patient.getId() == null) {
            em.persist(patient);
            return patient;
        }
        return em.merge(patient);
    }

    public void delete(Patient patient) {
        em.remove(em.contains(patient) ? patient : em.merge(patient));
    }
}
