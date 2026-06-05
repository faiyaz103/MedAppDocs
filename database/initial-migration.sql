-- =========================================================
-- Extensions
-- =========================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- Enum Types
-- =========================================================
CREATE TYPE user_status_enum AS ENUM (
  'pending',
  'active',
  'inactive',
  'suspended'
);

CREATE TYPE user_role_enum AS ENUM (
  'patient',
  'admin'
);

CREATE TYPE gender_enum AS ENUM (
  'male',
  'female',
  'other'
);

CREATE TYPE blood_group_enum AS ENUM (
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-'
);

CREATE TYPE weekday_enum AS ENUM (
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday'
);

-- =========================================================
-- Reusable updated_at trigger
-- =========================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Tables
-- =========================================================

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(254) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  status user_status_enum NOT NULL DEFAULT 'pending',
  is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  role user_role_enum NOT NULL DEFAULT 'patient',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE patient_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  dob DATE NOT NULL,
  gender gender_enum NOT NULL,
  blood_group blood_group_enum NULL,
  street VARCHAR(255) NULL,
  city VARCHAR(100) NULL,
  state VARCHAR(100) NULL,
  country VARCHAR(100) NULL,
  postal_code VARCHAR(20) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_patient_profiles_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE TABLE admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_admins_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

CREATE TABLE hospitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_admin_id UUID NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL UNIQUE,
  street VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100) NOT NULL,
  country VARCHAR(100) NOT NULL,
  postal_code VARCHAR(20) NOT NULL,
  logo_url TEXT NULL,
  cover_url TEXT NULL,
  has_blood_bank BOOLEAN NOT NULL DEFAULT FALSE,
  weekday_start weekday_enum NOT NULL,
  weekday_end weekday_enum NOT NULL,
  is_off_saturday BOOLEAN NOT NULL DEFAULT FALSE,
  is_off_sunday BOOLEAN NOT NULL DEFAULT FALSE,
  is_off_monday BOOLEAN NOT NULL DEFAULT FALSE,
  is_off_tuesday BOOLEAN NOT NULL DEFAULT FALSE,
  is_off_wednesday BOOLEAN NOT NULL DEFAULT FALSE,
  is_off_thursday BOOLEAN NOT NULL DEFAULT FALSE,
  is_off_friday BOOLEAN NOT NULL DEFAULT FALSE,
  search_count INTEGER NOT NULL DEFAULT 0 CHECK (search_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_hospitals_admin
    FOREIGN KEY (hospital_admin_id) REFERENCES admins(id)
    ON DELETE RESTRICT
);

CREATE TABLE awards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  title VARCHAR(200) NOT NULL UNIQUE,
  description TEXT NULL,
  file_url TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_awards_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE
);

CREATE TABLE doctor_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT NULL
);

CREATE TABLE doctors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  category_id UUID NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL UNIQUE,
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_doctors_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_doctors_category
    FOREIGN KEY (category_id) REFERENCES doctor_categories(id)
    ON DELETE RESTRICT
);

CREATE TABLE directors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  category_id UUID NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL UNIQUE,
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_directors_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_directors_category
    FOREIGN KEY (category_id) REFERENCES doctor_categories(id)
    ON DELETE SET NULL
);

CREATE TABLE package_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT NULL
);

CREATE TABLE discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(150) NOT NULL UNIQUE,
  description TEXT NULL,
  percentage NUMERIC(5,2) NOT NULL CHECK (percentage >= 0 AND percentage <= 100)
);

CREATE TABLE cashbacks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(150) NOT NULL UNIQUE,
  description TEXT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0)
);

CREATE TABLE health_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  category_id UUID NOT NULL,
  title VARCHAR(150) NOT NULL,
  description TEXT NULL,
  total_tests INTEGER NOT NULL DEFAULT 0 CHECK (total_tests >= 0),
  price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  image_url TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_health_packages_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_health_packages_category
    FOREIGN KEY (category_id) REFERENCES package_categories(id)
    ON DELETE RESTRICT
);

CREATE TABLE package_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  discount_id UUID NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_package_discounts_package
    FOREIGN KEY (package_id) REFERENCES health_packages(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_package_discounts_discount
    FOREIGN KEY (discount_id) REFERENCES discounts(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_package_discounts_package_discount
    UNIQUE (package_id, discount_id)
);

CREATE TABLE package_cashbacks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  cashback_id UUID NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_package_cashbacks_package
    FOREIGN KEY (package_id) REFERENCES health_packages(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_package_cashbacks_cashback
    FOREIGN KEY (cashback_id) REFERENCES cashbacks(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_package_cashbacks_package_cashback
    UNIQUE (package_id, cashback_id)
);

CREATE TABLE procedures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT NULL,
  CONSTRAINT fk_procedures_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE
);

CREATE TABLE investigations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT NULL,
  CONSTRAINT fk_investigations_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE
);

CREATE TABLE consultations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doctor_id UUID NOT NULL UNIQUE,
  CONSTRAINT fk_consultations_doctor
    FOREIGN KEY (doctor_id) REFERENCES doctors(id)
    ON DELETE CASCADE
);

CREATE TABLE facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT NULL,
  CONSTRAINT fk_facilities_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE
);

CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id UUID NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_services_hospital
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
    ON DELETE CASCADE
);

CREATE TABLE service_procedures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  procedure_id UUID NOT NULL,
  service_id UUID NOT NULL,
  CONSTRAINT fk_service_procedures_procedure
    FOREIGN KEY (procedure_id) REFERENCES procedures(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_service_procedures_service
    FOREIGN KEY (service_id) REFERENCES services(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_service_procedures_procedure_service
    UNIQUE (procedure_id, service_id)
);

CREATE TABLE service_investigations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investigation_id UUID NOT NULL,
  service_id UUID NOT NULL,
  CONSTRAINT fk_service_investigations_investigation
    FOREIGN KEY (investigation_id) REFERENCES investigations(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_service_investigations_service
    FOREIGN KEY (service_id) REFERENCES services(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_service_investigations_investigation_service
    UNIQUE (investigation_id, service_id)
);

CREATE TABLE service_consultations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  consultation_id UUID NOT NULL,
  service_id UUID NOT NULL,
  CONSTRAINT fk_service_consultations_consultation
    FOREIGN KEY (consultation_id) REFERENCES consultations(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_service_consultations_service
    FOREIGN KEY (service_id) REFERENCES services(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_service_consultations_consultation_service
    UNIQUE (consultation_id, service_id)
);

CREATE TABLE service_facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL,
  service_id UUID NOT NULL,
  CONSTRAINT fk_service_facilities_facility
    FOREIGN KEY (facility_id) REFERENCES facilities(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_service_facilities_service
    FOREIGN KEY (service_id) REFERENCES services(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_service_facilities_facility_service
    UNIQUE (facility_id, service_id)
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL,
  service_id UUID NOT NULL,
  rating NUMERIC(2,1) NOT NULL CHECK (rating >= 0 AND rating <= 5),
  comment TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_reviews_patient
    FOREIGN KEY (patient_id) REFERENCES patient_profiles(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_reviews_service
    FOREIGN KEY (service_id) REFERENCES services(id)
    ON DELETE CASCADE,
  CONSTRAINT uq_reviews_patient_service
    UNIQUE (patient_id, service_id)
);

CREATE TABLE advertisements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(150) NOT NULL,
  description TEXT NULL,
  image_url TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  terminated_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_advertisements_period
    CHECK (terminated_at > started_at)
);

-- =========================================================
-- Helpful Indexes for Foreign Keys / Query Performance
-- =========================================================

CREATE INDEX idx_patient_profiles_user_id ON patient_profiles(user_id);
CREATE INDEX idx_admins_user_id ON admins(user_id);
CREATE INDEX idx_hospitals_hospital_admin_id ON hospitals(hospital_admin_id);
CREATE INDEX idx_awards_hospital_id ON awards(hospital_id);
CREATE INDEX idx_doctors_hospital_id ON doctors(hospital_id);
CREATE INDEX idx_doctors_category_id ON doctors(category_id);
CREATE INDEX idx_directors_hospital_id ON directors(hospital_id);
CREATE INDEX idx_directors_category_id ON directors(category_id);
CREATE INDEX idx_health_packages_hospital_id ON health_packages(hospital_id);
CREATE INDEX idx_health_packages_category_id ON health_packages(category_id);
CREATE INDEX idx_package_discounts_package_id ON package_discounts(package_id);
CREATE INDEX idx_package_discounts_discount_id ON package_discounts(discount_id);
CREATE INDEX idx_package_cashbacks_package_id ON package_cashbacks(package_id);
CREATE INDEX idx_package_cashbacks_cashback_id ON package_cashbacks(cashback_id);
CREATE INDEX idx_procedures_hospital_id ON procedures(hospital_id);
CREATE INDEX idx_investigations_hospital_id ON investigations(hospital_id);
CREATE INDEX idx_consultations_doctor_id ON consultations(doctor_id);
CREATE INDEX idx_facilities_hospital_id ON facilities(hospital_id);
CREATE INDEX idx_services_hospital_id ON services(hospital_id);
CREATE INDEX idx_service_procedures_procedure_id ON service_procedures(procedure_id);
CREATE INDEX idx_service_procedures_service_id ON service_procedures(service_id);
CREATE INDEX idx_service_investigations_investigation_id ON service_investigations(investigation_id);
CREATE INDEX idx_service_investigations_service_id ON service_investigations(service_id);
CREATE INDEX idx_service_consultations_consultation_id ON service_consultations(consultation_id);
CREATE INDEX idx_service_consultations_service_id ON service_consultations(service_id);
CREATE INDEX idx_service_facilities_facility_id ON service_facilities(facility_id);
CREATE INDEX idx_service_facilities_service_id ON service_facilities(service_id);
CREATE INDEX idx_reviews_patient_id ON reviews(patient_id);
CREATE INDEX idx_reviews_service_id ON reviews(service_id);

-- =========================================================
-- updated_at triggers
-- =========================================================

CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_patient_profiles_set_updated_at
BEFORE UPDATE ON patient_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_admins_set_updated_at
BEFORE UPDATE ON admins
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_hospitals_set_updated_at
BEFORE UPDATE ON hospitals
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_awards_set_updated_at
BEFORE UPDATE ON awards
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_doctors_set_updated_at
BEFORE UPDATE ON doctors
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_directors_set_updated_at
BEFORE UPDATE ON directors
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_health_packages_set_updated_at
BEFORE UPDATE ON health_packages
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_package_discounts_set_updated_at
BEFORE UPDATE ON package_discounts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_package_cashbacks_set_updated_at
BEFORE UPDATE ON package_cashbacks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_services_set_updated_at
BEFORE UPDATE ON services
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_reviews_set_updated_at
BEFORE UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_advertisements_set_updated_at
BEFORE UPDATE ON advertisements
FOR EACH ROW EXECUTE FUNCTION set_updated_at();